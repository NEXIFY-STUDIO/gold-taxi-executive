import { initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { setRoleResolver, requireAdmin, requireDriver, ensureAuth, readUserRole, RoleResolver } from './roles';

initializeApp();

const db = getFirestore();

// Initialize the role resolver to use Firestore in production
setRoleResolver({
  readUserRole: async (uid: string): Promise<'admin' | 'driver' | 'passenger' | null> => {
    const userSnap = await db.doc(`users/${uid}`).get();
    const role = userSnap.data()?.role;
    if (role === 'admin' || role === 'driver' || role === 'passenger') {
      return role;
    }
    return null;
  },
});

type UserRole = 'admin' | 'driver' | 'passenger';
type DriverStatus = 'offline' | 'online' | 'busy' | 'offDuty';
type PaymentStatus = 'pending' | 'authorized' | 'captured' | 'failed' | 'refunded' | null;
type VehicleClass = 'standard' | 'comfort' | 'premium' | 'van';
type RideStatus =
  | 'draft'
  | 'searching'
  | 'accepted'
  | 'driverArriving'
  | 'arrived'
  | 'inProgress'
  | 'completed'
  | 'cancelled'
  | 'paymentFailed';

interface LocationInput {
  latitude: number;
  longitude: number;
  label?: string;
}

interface RideDoc {
  passengerId: string;
  driverId: string | null;
  vehicleId: string | null;
  status: RideStatus;
  pickup: LocationInput;
  dropoff: LocationInput;
  vehicleClass: VehicleClass;
  estimatedFare: number;
  finalFare: number | null;
  paymentStatus: PaymentStatus;
  currency: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}

interface DriverDoc {
  userId: string;
  status: DriverStatus;
  currentRideId: string | null;
  notificationTokens?: string[];
}

const REGION = 'europe-west6';

const RIDE_TRANSITIONS: Record<RideStatus, RideStatus[]> = {
  draft: ['searching', 'cancelled'],
  searching: ['accepted', 'cancelled'],
  accepted: ['driverArriving', 'arrived', 'cancelled'],
  driverArriving: ['arrived', 'cancelled'],
  arrived: ['inProgress', 'cancelled'],
  inProgress: ['completed', 'cancelled', 'paymentFailed'],
  completed: [],
  cancelled: [],
  paymentFailed: [],
};

const BASE_FARE: Record<VehicleClass, number> = {
  standard: 12,
  comfort: 17,
  premium: 26,
  van: 22,
};

const PER_KM: Record<VehicleClass, number> = {
  standard: 1.7,
  comfort: 2.3,
  premium: 3.4,
  van: 2.8,
};

// Re-export role functions for use in other modules
// These are now imported from ./roles and initialized with Firestore resolver
export { requireAdmin, requireDriver, ensureAuth, readUserRole, setRoleResolver, resetRoleResolver } from './roles';


async function findDriverByUserId(uid: string) {
  const q = await db.collection('drivers').where('userId', '==', uid).limit(1).get();
  if (q.empty) {
    throw new HttpsError('permission-denied', 'Driver profile not found.');
  }
  return q.docs[0];
}

function ensureLocation(value: unknown, field: string): LocationInput {
  if (!value || typeof value !== 'object') {
    throw new HttpsError('invalid-argument', `${field} must be an object.`);
  }
  const candidate = value as LocationInput;
  if (typeof candidate.latitude !== 'number' || typeof candidate.longitude !== 'number') {
    throw new HttpsError('invalid-argument', `${field} must include numeric latitude/longitude.`);
  }
  return {
    latitude: candidate.latitude,
    longitude: candidate.longitude,
    label: typeof candidate.label === 'string' ? candidate.label.trim() : undefined,
  };
}

function toRadians(v: number) {
  return (v * Math.PI) / 180;
}

function distanceKm(a: LocationInput, b: LocationInput): number {
  const earthRadiusKm = 6371;
  const dLat = toRadians(b.latitude - a.latitude);
  const dLng = toRadians(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(a.latitude)) *
      Math.cos(toRadians(b.latitude)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  return earthRadiusKm * (2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h)));
}

function estimateFare(pickup: LocationInput, dropoff: LocationInput, vehicleClass: VehicleClass): number {
  const km = distanceKm(pickup, dropoff);
  const raw = BASE_FARE[vehicleClass] + km * PER_KM[vehicleClass];
  return Math.round(raw * 100) / 100;
}

function assertTransition(current: RideStatus, next: RideStatus) {
  if (!RIDE_TRANSITIONS[current].includes(next)) {
    throw new HttpsError(
      'failed-precondition',
      `Invalid transition ${current} -> ${next}.`,
    );
  }
}

async function appendRideEvent(rideId: string, type: string, actorId: string, payload: Record<string, unknown> = {}) {
  await db.collection('ride_events').add({
    rideId,
    type,
    actorId,
    payload,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function getLockResponse(lockId: string): Promise<unknown | null> {
  const lockSnap = await db.doc(`command_locks/${lockId}`).get();
  if (!lockSnap.exists) return null;
  return lockSnap.data()?.response ?? null;
}

async function saveLockResponse(lockId: string, response: unknown): Promise<void> {
  await db.doc(`command_locks/${lockId}`).set(
    {
      response,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function sendPush(tokens: string[], title: string, body: string, data: Record<string, string>) {
  if (!tokens.length) return;
  await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });
}

async function passengerTokens(passengerId: string): Promise<string[]> {
  const user = await db.doc(`users/${passengerId}`).get();
  const raw = user.data()?.notificationTokens;
  if (!Array.isArray(raw)) return [];
  return raw.filter((item: unknown) => typeof item === 'string');
}

async function driverTokens(driverId: string): Promise<string[]> {
  const driverSnap = await db.doc(`drivers/${driverId}`).get();
  const driver = driverSnap.data() as DriverDoc | undefined;
  const localTokens = Array.isArray(driver?.notificationTokens)
    ? driver!.notificationTokens!.filter((item) => typeof item === 'string')
    : [];
  if (!driver?.userId) return localTokens;

  const userSnap = await db.doc(`users/${driver.userId}`).get();
  const userTokens = Array.isArray(userSnap.data()?.notificationTokens)
    ? userSnap.data()!.notificationTokens.filter((item: unknown) => typeof item === 'string')
    : [];
  return Array.from(new Set([...localTokens, ...userTokens]));
}

async function dispatchRideInternal(rideId: string, actorId: string) {
  const rideRef = db.doc(`rides/${rideId}`);
  let selectedDriverId: string | null = null;

  await db.runTransaction(async (tx) => {
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) {
      throw new HttpsError('not-found', 'Ride not found.');
    }
    const ride = rideSnap.data() as RideDoc;

    if (ride.status !== 'searching' || ride.driverId) {
      return;
    }

    const driversQ = db
      .collection('drivers')
      .where('status', 'in', ['online', 'idle'])
      .limit(10);
    const driversSnap = await tx.get(driversQ);
    if (driversSnap.empty) {
      return;
    }

    const candidate = driversSnap.docs.find((doc) => {
      const d = doc.data() as DriverDoc;
      return !d.currentRideId;
    });
    if (!candidate) {
      return;
    }

    selectedDriverId = candidate.id;
    tx.update(rideRef, {
      driverId: selectedDriverId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(candidate.ref, {
      currentRideId: rideId,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  if (!selectedDriverId) {
    await appendRideEvent(rideId, 'dispatch.no_driver', actorId);
    return { rideId, assigned: false };
  }

  await appendRideEvent(rideId, 'dispatch.offered', actorId, { driverId: selectedDriverId });
  const tokens = await driverTokens(selectedDriverId);
  if (!tokens.length) {
    await appendRideEvent(rideId, 'dispatch.offer_push_skipped', actorId, {
      reason: 'no_driver_tokens',
      driverId: selectedDriverId,
    });
  } else {
    await sendPush(tokens, 'New ride offer', 'You have a new ride request.', {
      rideId,
      eventType: 'ride.offer',
      shellIndex: '1',
      route: '/app',
    });
  }

  return { rideId, assigned: true, driverId: selectedDriverId };
}

export const registerDeviceToken = onCall({ region: REGION }, async (request) => {
  const uid = ensureAuth(request);
  const token = request.data?.token;
  const role = request.data?.role as UserRole | undefined;
  if (typeof token !== 'string' || token.trim().length < 20) {
    throw new HttpsError('invalid-argument', 'token is required.');
  }

  await db.doc(`users/${uid}`).set(
    {
      notificationTokens: FieldValue.arrayUnion(token.trim()),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  if (role === 'driver') {
    await requireDriver(request);
    const driverDoc = await findDriverByUserId(uid);
    await driverDoc.ref.set(
      {
        notificationTokens: FieldValue.arrayUnion(token.trim()),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  return { ok: true };
});

export const bootstrapUserProfile = onCall({ region: REGION }, async (request) => {
  const uid = ensureAuth(request);
  const existingRole = await readUserRole(uid);
  const role: UserRole = existingRole ?? 'passenger';

  await db.doc(`users/${uid}`).set(
    {
      uid,
      role,
      displayName: request.data?.displayName ?? '',
      phoneNumber: request.data?.phoneNumber ?? '',
      email: request.auth?.token?.email ?? '',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { uid, role };
});

export const bootstrapDriverProfile = onCall({ region: REGION }, async (request) => {
  const uid = ensureAuth(request);
  const role = await readUserRole(uid);
  if (role !== 'driver' && role !== 'admin') {
    throw new HttpsError('permission-denied', 'Driver profile bootstrap requires an approved driver role.');
  }
  const displayName = typeof request.data?.displayName === 'string' ? request.data.displayName.trim() : 'Driver';

  const existing = await db.collection('drivers').where('userId', '==', uid).limit(1).get();
  if (!existing.empty) {
    return { uid, driverId: existing.docs[0].id };
  }

  const driverRef = db.collection('drivers').doc();
  await driverRef.set({
    userId: uid,
    displayName,
    vehicleName: 'Mercedes S-Class',
    plateNumber: 'ZH 824 611',
    vehicleClass: 'premium',
    latitude: 47.3778,
    longitude: 8.5394,
    heading: 94,
    rating: 4.96,
    status: 'online',
    is_busy: false,
    currentRideId: null,
    notificationTokens: [],
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { uid, driverId: driverRef.id };
});

export const setDriverOnline = onCall({ region: REGION }, async (request) => {
  const uid = await requireDriver(request);
  const online = request.data?.online;
  if (typeof online !== 'boolean') {
    throw new HttpsError('invalid-argument', 'online is required.');
  }

  const driverDoc = await findDriverByUserId(uid);
  await driverDoc.ref.set(
    {
      status: online ? 'online' : 'offline',
      is_busy: false,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true, online };
});

export const createRide = onCall({ region: REGION }, async (request) => {
  const uid = ensureAuth(request);
  const pickup = ensureLocation(request.data?.pickup, 'pickup');
  const dropoff = ensureLocation(request.data?.dropoff, 'dropoff');
  const vehicleClass = (request.data?.vehicleClass ?? 'standard') as VehicleClass;
  const commandId = request.data?.commandId as string | undefined;

  if (!['standard', 'comfort', 'premium', 'van'].includes(vehicleClass)) {
    throw new HttpsError('invalid-argument', 'Invalid vehicleClass.');
  }

  if (commandId) {
    const cached = await getLockResponse(`createRide_${uid}_${commandId}`);
    if (cached) return cached;
  }

  const estimatedFare = estimateFare(pickup, dropoff, vehicleClass);
  const rideRef = db.collection('rides').doc();
  const ride: RideDoc = {
    passengerId: uid,
    driverId: null,
    vehicleId: null,
    status: 'searching',
    pickup,
    dropoff,
    vehicleClass,
    estimatedFare,
    finalFare: null,
    paymentStatus: 'pending',
    currency: 'CHF',
  };

  await rideRef.set({
    ...ride,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await appendRideEvent(rideRef.id, 'ride.created', uid, {
    vehicleClass,
    estimatedFare,
  });

  const dispatchResult = await dispatchRideInternal(rideRef.id, uid);
  const response = { rideId: rideRef.id, estimatedFare, dispatch: dispatchResult };

  if (commandId) {
    await saveLockResponse(`createRide_${uid}_${commandId}`, response);
  }
  return response;
});

export const dispatchRide = onCall({ region: REGION }, async (request) => {
  await requireAdmin(request);
  const actorId = ensureAuth(request);
  const rideId = request.data?.rideId as string | undefined;
  if (!rideId) {
    throw new HttpsError('invalid-argument', 'rideId is required.');
  }
  return dispatchRideInternal(rideId, actorId);
});

export const acceptRide = onCall({ region: REGION }, async (request) => {
  const uid = await requireDriver(request);
  const rideId = request.data?.rideId as string | undefined;
  const commandId = request.data?.commandId as string | undefined;
  if (!rideId) throw new HttpsError('invalid-argument', 'rideId is required.');

  if (commandId) {
    const cached = await getLockResponse(`acceptRide_${uid}_${rideId}_${commandId}`);
    if (cached) return cached;
  }

  const driverDoc = await findDriverByUserId(uid);
  await db.runTransaction(async (tx) => {
    const rideRef = db.doc(`rides/${rideId}`);
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) {
      throw new HttpsError('not-found', 'Ride not found.');
    }
    const ride = rideSnap.data() as RideDoc;
    if (ride.driverId !== driverDoc.id) {
      throw new HttpsError('permission-denied', 'Ride is not assigned to this driver.');
    }
    assertTransition(ride.status, 'accepted');
    tx.update(rideRef, {
      status: 'accepted',
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(driverDoc.ref, {
      status: 'busy',
      currentRideId: rideId,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  await appendRideEvent(rideId, 'ride.accepted', uid);
  const rideSnap = await db.doc(`rides/${rideId}`).get();
  const ride = rideSnap.data() as RideDoc;
  const passengerPushTokens = await passengerTokens(ride.passengerId);
  if (passengerPushTokens.length) {
    await sendPush(passengerPushTokens, 'Driver accepted', 'Your driver is on the way.', {
      rideId,
      eventType: 'ride.accepted',
      shellIndex: '0',
      route: '/app',
    });
  } else {
    await appendRideEvent(rideId, 'ride.accepted_push_skipped', uid, { reason: 'no_passenger_tokens' });
  }

  const response = { rideId, status: 'accepted' as const };
  if (commandId) {
    await saveLockResponse(`acceptRide_${uid}_${rideId}_${commandId}`, response);
  }
  return response;
});

export const declineRide = onCall({ region: REGION }, async (request) => {
  const uid = await requireDriver(request);
  const rideId = request.data?.rideId as string | undefined;
  const commandId = request.data?.commandId as string | undefined;
  if (!rideId) throw new HttpsError('invalid-argument', 'rideId is required.');

  if (commandId) {
    const cached = await getLockResponse(`declineRide_${uid}_${rideId}_${commandId}`);
    if (cached) return cached;
  }

  const driverDoc = await findDriverByUserId(uid);
  await db.runTransaction(async (tx) => {
    const rideRef = db.doc(`rides/${rideId}`);
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) throw new HttpsError('not-found', 'Ride not found.');
    const ride = rideSnap.data() as RideDoc;
    if (ride.driverId !== driverDoc.id) {
      throw new HttpsError('permission-denied', 'Ride is not assigned to this driver.');
    }
    if (ride.status !== 'searching') {
      throw new HttpsError('failed-precondition', 'Only searching rides can be declined.');
    }

    tx.update(rideRef, {
      driverId: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(driverDoc.ref, {
      currentRideId: null,
      status: 'online',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  await appendRideEvent(rideId, 'ride.declined', uid);
  const dispatch = await dispatchRideInternal(rideId, uid);
  const response = { rideId, declined: true, redispatch: dispatch };
  if (commandId) {
    await saveLockResponse(`declineRide_${uid}_${rideId}_${commandId}`, response);
  }
  return response;
});

export const driverArrived = onCall({ region: REGION }, async (request) => {
  const uid = await requireDriver(request);
  const rideId = request.data?.rideId as string | undefined;
  if (!rideId) throw new HttpsError('invalid-argument', 'rideId is required.');
  const driverDoc = await findDriverByUserId(uid);

  await db.runTransaction(async (tx) => {
    const rideRef = db.doc(`rides/${rideId}`);
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) throw new HttpsError('not-found', 'Ride not found.');
    const ride = rideSnap.data() as RideDoc;
    if (ride.driverId !== driverDoc.id) {
      throw new HttpsError('permission-denied', 'Ride is not assigned to this driver.');
    }
    const nextStatus: RideStatus = ride.status === 'accepted' ? 'arrived' : 'arrived';
    assertTransition(ride.status, nextStatus);
    tx.update(rideRef, {
      status: 'arrived',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  await appendRideEvent(rideId, 'ride.driver_arrived', uid);
  const ride = (await db.doc(`rides/${rideId}`).get()).data() as RideDoc;
  const tokens = await passengerTokens(ride.passengerId);
  if (tokens.length) {
    await sendPush(tokens, 'Driver arrived', 'Your driver is at pickup.', {
      rideId,
      eventType: 'ride.arrived',
      shellIndex: '0',
      route: '/app',
    });
  } else {
    await appendRideEvent(rideId, 'ride.arrived_push_skipped', uid, { reason: 'no_passenger_tokens' });
  }
  return { rideId, status: 'arrived' as const };
});

export const startRide = onCall({ region: REGION }, async (request) => {
  const uid = await requireDriver(request);
  const rideId = request.data?.rideId as string | undefined;
  if (!rideId) throw new HttpsError('invalid-argument', 'rideId is required.');
  const driverDoc = await findDriverByUserId(uid);

  await db.runTransaction(async (tx) => {
    const rideRef = db.doc(`rides/${rideId}`);
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) throw new HttpsError('not-found', 'Ride not found.');
    const ride = rideSnap.data() as RideDoc;
    if (ride.driverId !== driverDoc.id) {
      throw new HttpsError('permission-denied', 'Ride is not assigned to this driver.');
    }
    assertTransition(ride.status, 'inProgress');
    tx.update(rideRef, {
      status: 'inProgress',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  await appendRideEvent(rideId, 'ride.started', uid);
  return { rideId, status: 'inProgress' as const };
});

export const completeRide = onCall({ region: REGION }, async (request) => {
  const uid = await requireDriver(request);
  const rideId = request.data?.rideId as string | undefined;
  const finalFareInput = request.data?.finalFare;
  if (!rideId) throw new HttpsError('invalid-argument', 'rideId is required.');
  const driverDoc = await findDriverByUserId(uid);

  let passengerId = '';
  let finalFare = 0;
  await db.runTransaction(async (tx) => {
    const rideRef = db.doc(`rides/${rideId}`);
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) throw new HttpsError('not-found', 'Ride not found.');
    const ride = rideSnap.data() as RideDoc;
    if (ride.driverId !== driverDoc.id) {
      throw new HttpsError('permission-denied', 'Ride is not assigned to this driver.');
    }
    assertTransition(ride.status, 'completed');

    passengerId = ride.passengerId;
    const computedFare =
      typeof finalFareInput === 'number' && finalFareInput > 0
        ? finalFareInput
        : ride.estimatedFare;
    finalFare = Math.round(computedFare * 100) / 100;

    tx.update(rideRef, {
      status: 'completed',
      finalFare,
      paymentStatus: 'captured',
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(driverDoc.ref, {
      status: 'online',
      currentRideId: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  await appendRideEvent(rideId, 'ride.completed', uid, { finalFare });
  const tokens = await passengerTokens(passengerId);
  if (tokens.length) {
    await sendPush(tokens, 'Ride completed', `Final fare CHF ${finalFare.toFixed(2)}.`, {
      rideId,
      eventType: 'ride.completed',
      finalFare: finalFare.toFixed(2),
      shellIndex: '0',
      route: '/app',
    });
  } else {
    await appendRideEvent(rideId, 'ride.completed_push_skipped', uid, { reason: 'no_passenger_tokens' });
  }
  return { rideId, status: 'completed' as const, finalFare };
});

export const cancelRide = onCall({ region: REGION }, async (request) => {
  const uid = ensureAuth(request);
  const rideId = request.data?.rideId as string | undefined;
  const reason = typeof request.data?.reason === 'string' ? request.data.reason : 'Cancelled by passenger';
  if (!rideId) throw new HttpsError('invalid-argument', 'rideId is required.');

  let passengerId = '';
  let driverId: string | null = null;
  await db.runTransaction(async (tx) => {
    const rideRef = db.doc(`rides/${rideId}`);
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) throw new HttpsError('not-found', 'Ride not found.');
    const ride = rideSnap.data() as RideDoc;
    if (ride.passengerId !== uid) {
      throw new HttpsError('permission-denied', 'Ride is not owned by this passenger.');
    }
    assertTransition(ride.status, 'cancelled');
    passengerId = ride.passengerId;
    driverId = ride.driverId;
    tx.update(rideRef, {
      status: 'cancelled',
      paymentStatus: 'failed',
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (driverId) {
      const driverSnap = await tx.get(db.doc(`drivers/${driverId}`));
      if (driverSnap.exists) {
        tx.update(driverSnap.ref, {
          status: 'online',
          currentRideId: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
  });

  await appendRideEvent(rideId, 'ride.cancelled', passengerId, { reason });
  const tokens = await passengerTokens(passengerId);
  if (tokens.length) {
    await sendPush(tokens, 'Ride cancelled', reason, {
      rideId,
      eventType: 'ride.cancelled',
      shellIndex: '0',
      route: '/app',
    });
  }
  return { rideId, status: 'cancelled' as const };
});

export const opsCancelRide = onCall({ region: REGION }, async (request) => {
  await requireAdmin(request);
  const actorId = ensureAuth(request);
  const rideId = request.data?.rideId as string | undefined;
  const reason = typeof request.data?.reason === 'string' ? request.data.reason : 'Cancelled by ops';
  if (!rideId) throw new HttpsError('invalid-argument', 'rideId is required.');

  let passengerId = '';
  let driverId: string | null = null;
  await db.runTransaction(async (tx) => {
    const rideRef = db.doc(`rides/${rideId}`);
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) throw new HttpsError('not-found', 'Ride not found.');
    const ride = rideSnap.data() as RideDoc;
    assertTransition(ride.status, 'cancelled');
    passengerId = ride.passengerId;
    driverId = ride.driverId;
    tx.update(rideRef, {
      status: 'cancelled',
      paymentStatus: 'failed',
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (driverId) {
      const driverSnap = await tx.get(db.doc(`drivers/${driverId}`));
      if (driverSnap.exists) {
        tx.update(driverSnap.ref, {
          status: 'online',
          currentRideId: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
  });

  await appendRideEvent(rideId, 'ride.cancelled_by_ops', actorId, { reason });
  const tokens = await passengerTokens(passengerId);
  if (tokens.length) {
    await sendPush(tokens, 'Ride cancelled', reason, {
      rideId,
      eventType: 'ride.cancelled',
      shellIndex: '0',
      route: '/app',
    });
  }
  return { rideId, status: 'cancelled' as const };
});

export const logRideLifecycle = onDocumentWritten(
  { document: 'rides/{rideId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data() as RideDoc | undefined;
    const after = event.data?.after.data() as RideDoc | undefined;
    if (!after) return;
    if (before?.status === after.status) return;

    await db.collection('ride_events').add({
      rideId: event.params.rideId,
      type: `ride.${after.status}`,
      actorId: after.driverId ?? after.passengerId,
      payload: {
        beforeStatus: before?.status ?? null,
        afterStatus: after.status,
        vehicleClass: after.vehicleClass,
      },
      createdAt: FieldValue.serverTimestamp(),
    });
  },
);

export const syncPaymentStatus = onDocumentCreated(
  { document: 'payments/{paymentId}', region: REGION },
  async (event) => {
    const payment = event.data?.data();
    if (!payment || !payment.rideId) return;

    await db.doc(`rides/${payment.rideId}`).set(
      {
        paymentStatus: payment.status,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (payment.status === 'failed') {
      const rideSnap = await db.doc(`rides/${payment.rideId}`).get();
      const ride = rideSnap.data() as RideDoc | undefined;
      if (!ride) return;

      const tokens = await passengerTokens(ride.passengerId);
      if (tokens.length) {
        await sendPush(tokens, 'Payment failed', 'Please update your payment method.', {
          rideId: payment.rideId,
          eventType: 'payment.failed',
          shellIndex: '0',
          route: '/app',
        });
      } else {
        await appendRideEvent(payment.rideId, 'payment.failed_push_skipped', 'system', {
          reason: 'no_passenger_tokens',
        });
      }
    }
  },
);

export const seedRideEventFromManualAction = onCall({ region: REGION }, async (request) => {
  await requireAdmin(request);
  const actorId = ensureAuth(request);
  const rideId = request.data?.rideId as string | undefined;
  const type = request.data?.type as string | undefined;
  const payload = request.data?.payload;

  if (!rideId || !type) {
    throw new HttpsError('invalid-argument', 'rideId and type are required.');
  }

  await appendRideEvent(
    rideId,
    `ops.${type}`,
    actorId,
    payload && typeof payload === 'object' ? payload : {},
  );
  return { ok: true };
});
