import { HttpsError } from 'firebase-functions/v2/https';

type UserRole = 'admin' | 'driver' | 'passenger';
type VehicleClass = 'standard' | 'comfort' | 'premium' | 'van';
type DriverApplicationVehicleClass = 'basic' | 'premium' | 'executive';
type DriverApplicationStatus = 'pending' | 'approved' | 'rejected';

const VEHICLE_CLASSES: VehicleClass[] = ['standard', 'comfort', 'premium', 'van'];
const APPLICATION_VEHICLE_CLASSES: DriverApplicationVehicleClass[] = [
  'basic',
  'premium',
  'executive',
];

export interface AuthUserRecord {
  uid: string;
  email?: string;
  displayName?: string;
  customClaims?: Record<string, unknown>;
}

export interface ExistingDriverRecord {
  id: string;
  data: Record<string, unknown>;
}

export interface DriverProvisioningDeps {
  readUserRole(uid: string): Promise<UserRole | null>;
  getAuthUser(uid: string): Promise<AuthUserRecord | null>;
  setCustomUserClaims(uid: string, claims: Record<string, unknown>): Promise<void>;
  findDriverByUserId(uid: string): Promise<ExistingDriverRecord | null>;
  setUserProfile(uid: string, data: Record<string, unknown>): Promise<void>;
  setDriverProfile(driverId: string | null, data: Record<string, unknown>): Promise<string>;
  now(): unknown;
}

export interface ExistingDriverApplicationRecord {
  id: string;
  data: Record<string, unknown>;
}

export interface DriverApplicationDeps extends DriverProvisioningDeps {
  findPendingDriverApplicationByUserId(uid: string): Promise<ExistingDriverApplicationRecord | null>;
  getDriverApplication(applicationId: string): Promise<ExistingDriverApplicationRecord | null>;
  setDriverApplication(applicationId: string | null, data: Record<string, unknown>): Promise<string>;
  updateDriverApplication(applicationId: string, data: Record<string, unknown>): Promise<void>;
}

export interface DriverApprovalData {
  targetUid: string;
  name: string;
  phone: string;
  vehicleLabel: string;
  licensePlate: string;
  vehicleClass: VehicleClass;
}

export interface DriverApprovalResult {
  uid: string;
  role: 'driver';
  driverId: string;
}

export interface DriverApplicationInput {
  fullName: string;
  phone: string;
  vehicleLabel: string;
  licensePlate: string;
  vehicleClass: DriverApplicationVehicleClass;
}

export async function submitDriverApplicationForUser(params: {
  actorUid: string;
  data?: Record<string, unknown>;
  deps: DriverApplicationDeps;
}): Promise<{ applicationId: string; status: 'pending' }> {
  const actorRole = await params.deps.readUserRole(params.actorUid);
  if (actorRole !== 'passenger') {
    throw new HttpsError('permission-denied', 'Passenger role required.');
  }

  const input = readDriverApplicationInput(params.data);
  const timestamp = params.deps.now();
  const existing = await params.deps.findPendingDriverApplicationByUserId(params.actorUid);
  const applicationId = await params.deps.setDriverApplication(existing?.id ?? null, {
    userId: params.actorUid,
    fullName: input.fullName,
    phone: input.phone,
    vehicleLabel: input.vehicleLabel,
    licensePlate: input.licensePlate,
    vehicleClass: input.vehicleClass,
    status: 'pending',
    ...(existing ? {} : { createdAt: timestamp }),
    updatedAt: timestamp,
  });

  return {
    applicationId,
    status: 'pending',
  };
}

export async function approveDriverApplication(params: {
  actorUid: string;
  applicationId: string;
  deps: DriverApplicationDeps;
}): Promise<DriverApprovalResult & { applicationId: string }> {
  const actorRole = await params.deps.readUserRole(params.actorUid);
  if (actorRole !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin role required.');
  }

  const application = await params.deps.getDriverApplication(params.applicationId);
  if (!application) {
    throw new HttpsError('not-found', 'Driver application not found.');
  }

  const request = readDriverApplicationRecord(application.data);
  if (request.userId === params.actorUid) {
    throw new HttpsError('permission-denied', 'Admins cannot approve their own account as driver.');
  }
  if (request.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Driver application is not pending.');
  }

  const result = await approveDriverForUser({
    actorUid: params.actorUid,
    data: {
      targetUid: request.userId,
      name: request.fullName,
      phone: request.phone,
      vehicleLabel: request.vehicleLabel,
      licensePlate: request.licensePlate,
      vehicleClass: mapApplicationVehicleClass(request.vehicleClass),
    },
    deps: params.deps,
  });

  await params.deps.updateDriverApplication(params.applicationId, {
    status: 'approved',
    reviewedBy: params.actorUid,
    reviewedAt: params.deps.now(),
    driverId: result.driverId,
    updatedAt: params.deps.now(),
  });

  return {
    ...result,
    applicationId: params.applicationId,
  };
}

export async function rejectDriverApplication(params: {
  actorUid: string;
  data?: Record<string, unknown>;
  deps: DriverApplicationDeps;
}): Promise<{ applicationId: string; status: 'rejected' }> {
  const actorRole = await params.deps.readUserRole(params.actorUid);
  if (actorRole !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin role required.');
  }

  const applicationId = readRequiredText(params.data?.applicationId, 'applicationId', 160);
  const application = await params.deps.getDriverApplication(applicationId);
  if (!application) {
    throw new HttpsError('not-found', 'Driver application not found.');
  }

  const request = readDriverApplicationRecord(application.data);
  if (request.userId === params.actorUid) {
    throw new HttpsError('permission-denied', 'Admins cannot reject their own driver request.');
  }
  if (request.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Driver application is not pending.');
  }

  await params.deps.updateDriverApplication(applicationId, {
    status: 'rejected',
    rejectionReason: readOptionalText(params.data?.reason, 180) ?? 'Rejected by operations',
    reviewedBy: params.actorUid,
    reviewedAt: params.deps.now(),
    updatedAt: params.deps.now(),
  });

  return {
    applicationId,
    status: 'rejected',
  };
}

export async function approveDriverForUser(params: {
  actorUid: string;
  data?: Record<string, unknown>;
  deps: DriverProvisioningDeps;
}): Promise<DriverApprovalResult> {
  const actorRole = await params.deps.readUserRole(params.actorUid);
  if (actorRole !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin role required.');
  }

  const input = readDriverApprovalData(params.data);
  if (input.targetUid === params.actorUid) {
    throw new HttpsError('permission-denied', 'Admins cannot approve their own account as driver.');
  }

  const targetUser = await params.deps.getAuthUser(input.targetUid);
  if (!targetUser) {
    throw new HttpsError('not-found', 'Registered passenger account not found.');
  }

  const targetRole = await params.deps.readUserRole(input.targetUid);
  if (targetRole === 'admin') {
    throw new HttpsError('permission-denied', 'Admin accounts cannot be converted into drivers.');
  }
  if (targetRole === null) {
    throw new HttpsError('failed-precondition', 'Passenger profile must exist before driver approval.');
  }
  if (targetRole !== 'passenger' && targetRole !== 'driver') {
    throw new HttpsError('failed-precondition', 'Unsupported target role.');
  }

  const timestamp = params.deps.now();
  const existingDriver = await params.deps.findDriverByUserId(input.targetUid);
  const mergedClaims = {
    ...(targetUser.customClaims ?? {}),
    role: 'driver',
  };

  await params.deps.setUserProfile(input.targetUid, {
    uid: input.targetUid,
    role: 'driver',
    displayName: input.name,
    phoneNumber: input.phone,
    email: targetUser.email ?? '',
    driverApprovedAt: timestamp,
    driverApprovedBy: params.actorUid,
    updatedAt: timestamp,
  });

  const driverId = await params.deps.setDriverProfile(existingDriver?.id ?? null, {
    userId: input.targetUid,
    displayName: input.name,
    display_name: input.name,
    phoneNumber: input.phone,
    phone_number: input.phone,
    vehicleName: input.vehicleLabel,
    vehicle_name: input.vehicleLabel,
    plateNumber: input.licensePlate,
    plate_number: input.licensePlate,
    vehicleClass: input.vehicleClass,
    vehicle_class: input.vehicleClass,
    latitude: readNumber(existingDriver?.data.latitude, 47.3769),
    longitude: readNumber(existingDriver?.data.longitude, 8.5417),
    heading: readNumber(existingDriver?.data.heading, 0),
    rating: readNumber(existingDriver?.data.rating, 5),
    status: readString(existingDriver?.data.status, 'offline'),
    is_busy: existingDriver?.data.is_busy === true,
    currentRideId: existingDriver?.data.currentRideId ?? null,
    notificationTokens: Array.isArray(existingDriver?.data.notificationTokens)
      ? existingDriver!.data.notificationTokens
      : [],
    approvedAt: timestamp,
    approvedBy: params.actorUid,
    ...(existingDriver ? {} : { createdAt: timestamp }),
    updatedAt: timestamp,
  });

  await params.deps.setCustomUserClaims(input.targetUid, mergedClaims);

  return {
    uid: input.targetUid,
    role: 'driver',
    driverId,
  };
}

export function readDriverApplicationInput(data?: Record<string, unknown>): DriverApplicationInput {
  return {
    fullName: readRequiredText(data?.fullName, 'fullName', 120),
    phone: readRequiredText(data?.phone, 'phone', 40),
    vehicleLabel: readRequiredText(data?.vehicleLabel, 'vehicleLabel', 120),
    licensePlate: readRequiredText(data?.licensePlate, 'licensePlate', 40).toUpperCase(),
    vehicleClass: readApplicationVehicleClass(data?.vehicleClass),
  };
}

export function readDriverApprovalData(data?: Record<string, unknown>): DriverApprovalData {
  const vehicleClass = readVehicleClass(data?.vehicleClass);
  return {
    targetUid: readRequiredText(data?.targetUid, 'targetUid', 160),
    name: readRequiredText(data?.name, 'name', 120),
    phone: readRequiredText(data?.phone, 'phone', 40),
    vehicleLabel: readRequiredText(data?.vehicleLabel, 'vehicleLabel', 120),
    licensePlate: readRequiredText(data?.licensePlate, 'licensePlate', 40).toUpperCase(),
    vehicleClass,
  };
}

function readDriverApplicationRecord(data: Record<string, unknown>): DriverApplicationInput & {
  userId: string;
  status: DriverApplicationStatus;
} {
  return {
    userId: readRequiredText(data.userId, 'userId', 160),
    fullName: readRequiredText(data.fullName, 'fullName', 120),
    phone: readRequiredText(data.phone, 'phone', 40),
    vehicleLabel: readRequiredText(data.vehicleLabel, 'vehicleLabel', 120),
    licensePlate: readRequiredText(data.licensePlate, 'licensePlate', 40).toUpperCase(),
    vehicleClass: readApplicationVehicleClass(data.vehicleClass),
    status: readDriverApplicationStatus(data.status),
  };
}

function readRequiredText(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  const trimmed = value.trim();
  if (!trimmed) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  if (trimmed.length > maxLength) {
    throw new HttpsError('invalid-argument', `${field} is too long.`);
  }
  return trimmed;
}

function readOptionalText(value: unknown, maxLength: number): string | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'reason must be text.');
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  if (trimmed.length > maxLength) {
    throw new HttpsError('invalid-argument', 'reason is too long.');
  }
  return trimmed;
}

function readVehicleClass(value: unknown): VehicleClass {
  if (typeof value !== 'string' || !VEHICLE_CLASSES.includes(value as VehicleClass)) {
    throw new HttpsError('invalid-argument', 'vehicleClass is invalid.');
  }
  return value as VehicleClass;
}

function readApplicationVehicleClass(value: unknown): DriverApplicationVehicleClass {
  if (
    typeof value !== 'string' ||
    !APPLICATION_VEHICLE_CLASSES.includes(value as DriverApplicationVehicleClass)
  ) {
    throw new HttpsError('invalid-argument', 'vehicleClass is invalid.');
  }
  return value as DriverApplicationVehicleClass;
}

function readDriverApplicationStatus(value: unknown): DriverApplicationStatus {
  if (value === 'pending' || value === 'approved' || value === 'rejected') {
    return value;
  }
  throw new HttpsError('failed-precondition', 'Driver application status is invalid.');
}

function mapApplicationVehicleClass(value: DriverApplicationVehicleClass): VehicleClass {
  switch (value) {
    case 'basic':
      return 'standard';
    case 'premium':
      return 'comfort';
    case 'executive':
      return 'premium';
  }
}

function readNumber(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function readString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim() ? value : fallback;
}
