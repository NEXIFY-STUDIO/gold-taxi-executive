import { HttpsError } from 'firebase-functions/v2/https';
import {
  approveDriverApplication,
  approveDriverForUser,
  DriverApplicationDeps,
  rejectDriverApplication,
  submitDriverApplicationForUser,
} from './driver_provisioning';

describe('Driver provisioning', () => {
  it('rejects passenger actors', async () => {
    const deps = createDeps({ admin: 'passenger', passenger: 'passenger' });

    await expect(
      approveDriverForUser({
        actorUid: 'admin',
        data: validApprovalData(),
        deps,
      }),
    ).rejects.toThrow(HttpsError);
    expect(deps.driverWrites).toEqual([]);
  });

  it('rejects driver actors', async () => {
    const deps = createDeps({ driver: 'driver', passenger: 'passenger' });

    await expect(
      approveDriverForUser({
        actorUid: 'driver',
        data: validApprovalData(),
        deps,
      }),
    ).rejects.toThrow('Admin role required.');
    expect(deps.claimWrites).toEqual([]);
  });

  it('rejects admin self approval', async () => {
    const deps = createDeps({ admin: 'admin' });

    await expect(
      approveDriverForUser({
        actorUid: 'admin',
        data: validApprovalData({ targetUid: 'admin' }),
        deps,
      }),
    ).rejects.toThrow('Admins cannot approve their own account as driver.');
  });

  it('approves a passenger and writes driver profile plus role claim', async () => {
    const deps = createDeps({ admin: 'admin', passenger: 'passenger' });

    const result = await approveDriverForUser({
      actorUid: 'admin',
      data: validApprovalData(),
      deps,
    });

    expect(result).toEqual({
      uid: 'passenger',
      role: 'driver',
      driverId: 'driver-passenger',
    });
    expect(deps.claimWrites).toEqual([
      { uid: 'passenger', claims: { existing: true, role: 'driver' } },
    ]);
    expect(deps.userWrites[0]).toMatchObject({
      uid: 'passenger',
      data: {
        role: 'driver',
        displayName: 'Erik Driver',
        phoneNumber: '+421900000000',
        driverApprovedBy: 'admin',
      },
    });
    expect(deps.driverWrites[0].data).toMatchObject({
      userId: 'passenger',
      displayName: 'Erik Driver',
      display_name: 'Erik Driver',
      vehicleName: 'Mercedes S-Class',
      vehicle_name: 'Mercedes S-Class',
      plateNumber: 'ZH 824 611',
      plate_number: 'ZH 824 611',
      vehicleClass: 'premium',
      vehicle_class: 'premium',
      status: 'offline',
      is_busy: false,
    });
  });

  it('lets passengers create a pending driver application', async () => {
    const deps = createDeps({ passenger: 'passenger' });

    const result = await submitDriverApplicationForUser({
      actorUid: 'passenger',
      data: validApplicationData(),
      deps,
    });

    expect(result).toEqual({
      applicationId: 'application-passenger',
      status: 'pending',
    });
    expect(deps.applicationWrites[0].data).toMatchObject({
      userId: 'passenger',
      fullName: 'Erik Driver',
      phone: '+421900000000',
      vehicleLabel: 'Mercedes S-Class',
      licensePlate: 'ZH 824 611',
      vehicleClass: 'executive',
      status: 'pending',
    });
    expect(deps.claimWrites).toEqual([]);
  });

  it('rejects driver actors approving applications', async () => {
    const deps = createDeps({ driver: 'driver', passenger: 'passenger' });
    deps.applications.set('application-passenger', pendingApplication());

    await expect(
      approveDriverApplication({
        actorUid: 'driver',
        applicationId: 'application-passenger',
        deps,
      }),
    ).rejects.toThrow('Admin role required.');
    expect(deps.driverWrites).toEqual([]);
  });

  it('rejects passenger actors approving applications', async () => {
    const deps = createDeps({ passenger: 'passenger' });
    deps.applications.set('application-passenger', pendingApplication());

    await expect(
      approveDriverApplication({
        actorUid: 'passenger',
        applicationId: 'application-passenger',
        deps,
      }),
    ).rejects.toThrow('Admin role required.');
    expect(deps.driverWrites).toEqual([]);
  });

  it('approves pending applications and creates driver profile', async () => {
    const deps = createDeps({ admin: 'admin', passenger: 'passenger' });
    deps.applications.set('application-passenger', pendingApplication());

    const result = await approveDriverApplication({
      actorUid: 'admin',
      applicationId: 'application-passenger',
      deps,
    });

    expect(result).toMatchObject({
      uid: 'passenger',
      role: 'driver',
      driverId: 'driver-passenger',
      applicationId: 'application-passenger',
    });
    expect(deps.userWrites[0].data.role).toBe('driver');
    expect(deps.driverWrites[0].data).toMatchObject({
      userId: 'passenger',
      vehicleName: 'Mercedes S-Class',
      plateNumber: 'ZH 824 611',
      vehicleClass: 'premium',
      status: 'offline',
    });
    expect(deps.applicationUpdates[0]).toMatchObject({
      applicationId: 'application-passenger',
      data: {
        status: 'approved',
        reviewedBy: 'admin',
        driverId: 'driver-passenger',
      },
    });
  });

  it('rejects applications without creating driver role', async () => {
    const deps = createDeps({ admin: 'admin', passenger: 'passenger' });
    deps.applications.set('application-passenger', pendingApplication());

    const result = await rejectDriverApplication({
      actorUid: 'admin',
      data: {
        applicationId: 'application-passenger',
        reason: 'Incomplete documents',
      },
      deps,
    });

    expect(result).toEqual({
      applicationId: 'application-passenger',
      status: 'rejected',
    });
    expect(deps.claimWrites).toEqual([]);
    expect(deps.userWrites).toEqual([]);
    expect(deps.driverWrites).toEqual([]);
    expect(deps.applicationUpdates[0]).toMatchObject({
      applicationId: 'application-passenger',
      data: {
        status: 'rejected',
        rejectionReason: 'Incomplete documents',
        reviewedBy: 'admin',
      },
    });
  });
});

function validApprovalData(overrides: Record<string, unknown> = {}) {
  return {
    targetUid: 'passenger',
    name: 'Erik Driver',
    phone: '+421900000000',
    vehicleLabel: 'Mercedes S-Class',
    licensePlate: 'zh 824 611',
    vehicleClass: 'premium',
    ...overrides,
  };
}

function validApplicationData(overrides: Record<string, unknown> = {}) {
  return {
    fullName: 'Erik Driver',
    phone: '+421900000000',
    vehicleLabel: 'Mercedes S-Class',
    licensePlate: 'zh 824 611',
    vehicleClass: 'executive',
    ...overrides,
  };
}

function pendingApplication(overrides: Record<string, unknown> = {}) {
  return {
    userId: 'passenger',
    fullName: 'Erik Driver',
    phone: '+421900000000',
    vehicleLabel: 'Mercedes S-Class',
    licensePlate: 'ZH 824 611',
    vehicleClass: 'executive',
    status: 'pending',
    ...overrides,
  };
}

function createDeps(roles: Record<string, 'admin' | 'driver' | 'passenger' | null>) {
  const claimWrites: Array<{ uid: string; claims: Record<string, unknown> }> = [];
  const userWrites: Array<{ uid: string; data: Record<string, unknown> }> = [];
  const driverWrites: Array<{ driverId: string | null; data: Record<string, unknown> }> = [];
  const applicationWrites: Array<{ applicationId: string | null; data: Record<string, unknown> }> = [];
  const applicationUpdates: Array<{ applicationId: string; data: Record<string, unknown> }> = [];
  const applications = new Map<string, Record<string, unknown>>();

  const deps: DriverApplicationDeps & {
    claimWrites: typeof claimWrites;
    userWrites: typeof userWrites;
    driverWrites: typeof driverWrites;
    applicationWrites: typeof applicationWrites;
    applicationUpdates: typeof applicationUpdates;
    applications: typeof applications;
  } = {
    claimWrites,
    userWrites,
    driverWrites,
    applicationWrites,
    applicationUpdates,
    applications,
    readUserRole: async (uid: string) => roles[uid] ?? null,
    getAuthUser: async (uid: string) =>
      uid === 'missing'
        ? null
        : {
            uid,
            email: `${uid}@example.com`,
            displayName: 'Existing User',
            customClaims: { existing: true },
          },
    setCustomUserClaims: async (uid: string, claims: Record<string, unknown>) => {
      claimWrites.push({ uid, claims });
    },
    findDriverByUserId: async () => null,
    setUserProfile: async (uid: string, data: Record<string, unknown>) => {
      userWrites.push({ uid, data });
    },
    setDriverProfile: async (driverId: string | null, data: Record<string, unknown>) => {
      driverWrites.push({ driverId, data });
      return driverId ?? `driver-${data.userId}`;
    },
    findPendingDriverApplicationByUserId: async (uid: string) => {
      const match = Array.from(applications.entries()).find(([, data]) => {
        return data.userId === uid && data.status === 'pending';
      });
      if (!match) return null;
      return { id: match[0], data: match[1] };
    },
    getDriverApplication: async (applicationId: string) => {
      const data = applications.get(applicationId);
      return data ? { id: applicationId, data } : null;
    },
    setDriverApplication: async (applicationId: string | null, data: Record<string, unknown>) => {
      const id = applicationId ?? `application-${data.userId}`;
      applications.set(id, data);
      applicationWrites.push({ applicationId, data });
      return id;
    },
    updateDriverApplication: async (applicationId: string, data: Record<string, unknown>) => {
      applications.set(applicationId, {
        ...(applications.get(applicationId) ?? {}),
        ...data,
      });
      applicationUpdates.push({ applicationId, data });
    },
    now: () => 'SERVER_TIME',
  };
  return deps;
}
