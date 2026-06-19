import { HttpsError } from 'firebase-functions/v2/https';
import {
  approveDriverForUser,
  DriverProvisioningDeps,
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

function createDeps(roles: Record<string, 'admin' | 'driver' | 'passenger' | null>) {
  const claimWrites: Array<{ uid: string; claims: Record<string, unknown> }> = [];
  const userWrites: Array<{ uid: string; data: Record<string, unknown> }> = [];
  const driverWrites: Array<{ driverId: string | null; data: Record<string, unknown> }> = [];

  const deps: DriverProvisioningDeps & {
    claimWrites: typeof claimWrites;
    userWrites: typeof userWrites;
    driverWrites: typeof driverWrites;
  } = {
    claimWrites,
    userWrites,
    driverWrites,
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
    now: () => 'SERVER_TIME',
  };
  return deps;
}
