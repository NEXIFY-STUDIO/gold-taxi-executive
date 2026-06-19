import { HttpsError } from 'firebase-functions/v2/https';
import {
  requireAdmin,
  requireDriver,
  ensureAuth,
  readUserRole,
  setRoleResolver,
  resetRoleResolver,
  RoleResolver,
  requirePassenger,
} from './roles';

// Mock request objects for testing
type TestRequest = {
  auth?: {
    uid: string;
    token?: {
      role?: string;
      email?: string;
    };
  };
  data?: Record<string, unknown>;
};

// Helper to create test requests
function createRequest(auth?: { uid: string; token?: { role?: string } }): TestRequest {
  return { auth };
}

// Helper to create a mock role resolver
function createMockResolver(roles: Record<string, 'admin' | 'driver' | 'passenger' | null>): RoleResolver {
  return {
    readUserRole: async (uid: string) => {
      const role = roles[uid];
      // Only return valid roles or null
      if (role === 'admin' || role === 'driver' || role === 'passenger') {
        return role;
      }
      return null;
    },
  };
}

describe('Role Enforcement Tests', () => {
  beforeEach(() => {
    // Reset role resolver before each test
    resetRoleResolver();
  });

  afterEach(() => {
    // Clean up after each test
    resetRoleResolver();
  });

  describe('ensureAuth', () => {
    it('should return UID for authenticated request', () => {
      const request = createRequest({ uid: 'user123' });
      const uid = ensureAuth(request);
      expect(uid).toBe('user123');
    });

    it('should throw HttpsError for unauthenticated request', () => {
      const request = createRequest();
      expect(() => ensureAuth(request)).toThrow(HttpsError);
      expect(() => ensureAuth(request)).toThrow('Login required.');
    });
  });

  describe('requireAdmin', () => {
    it('should allow admin user via token claims', async () => {
      const request = createRequest({
        uid: 'admin123',
        token: { role: 'admin' },
      });
      
      await expect(requireAdmin(request)).resolves.not.toThrow();
    });

    it('should allow admin user via Firestore role', async () => {
      const request = createRequest({ uid: 'admin456' });
      setRoleResolver(createMockResolver({ admin456: 'admin' }));
      
      await expect(requireAdmin(request)).resolves.not.toThrow();
    });

    it('should reject unauthenticated user', async () => {
      const request = createRequest();
      
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Login required.');
    });

    it('should reject passenger user via token claims', async () => {
      const request = createRequest({
        uid: 'passenger123',
        token: { role: 'passenger' },
      });
      setRoleResolver(createMockResolver({ passenger123: 'passenger' }));
      
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Admin role required.');
    });

    it('should reject passenger user via Firestore role', async () => {
      const request = createRequest({ uid: 'passenger456' });
      setRoleResolver(createMockResolver({ passenger456: 'passenger' }));
      
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Admin role required.');
    });

    it('should reject driver user via token claims', async () => {
      const request = createRequest({
        uid: 'driver123',
        token: { role: 'driver' },
      });
      setRoleResolver(createMockResolver({ driver123: 'driver' }));
      
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Admin role required.');
    });

    it('should reject driver user via Firestore role', async () => {
      const request = createRequest({ uid: 'driver456' });
      setRoleResolver(createMockResolver({ driver456: 'driver' }));
      
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Admin role required.');
    });

    it('should reject user with no role in Firestore', async () => {
      const request = createRequest({ uid: 'nobody' });
      setRoleResolver(createMockResolver({ nobody: null }));
      
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Admin role required.');
    });
  });

  describe('requireDriver', () => {
    it('should allow driver user via token claims and return UID', async () => {
      const request = createRequest({
        uid: 'driver123',
        token: { role: 'driver' },
      });
      
      const uid = await requireDriver(request);
      expect(uid).toBe('driver123');
    });

    it('should allow driver user via Firestore role and return UID', async () => {
      const request = createRequest({ uid: 'driver456' });
      setRoleResolver(createMockResolver({ driver456: 'driver' }));
      
      const uid = await requireDriver(request);
      expect(uid).toBe('driver456');
    });

    it('should reject unauthenticated user', async () => {
      const request = createRequest();
      
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Login required.');
    });

    it('should reject passenger user via token claims', async () => {
      const request = createRequest({
        uid: 'passenger123',
        token: { role: 'passenger' },
      });
      setRoleResolver(createMockResolver({ passenger123: 'passenger' }));
      
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Driver role required.');
    });

    it('should reject passenger user via Firestore role', async () => {
      const request = createRequest({ uid: 'passenger456' });
      setRoleResolver(createMockResolver({ passenger456: 'passenger' }));
      
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Driver role required.');
    });

    it('should reject admin user via token claims', async () => {
      const request = createRequest({
        uid: 'admin123',
        token: { role: 'admin' },
      });
      setRoleResolver(createMockResolver({ admin123: 'admin' }));
      
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Driver role required.');
    });

    it('should reject admin user via Firestore role', async () => {
      const request = createRequest({ uid: 'admin456' });
      setRoleResolver(createMockResolver({ admin456: 'admin' }));
      
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Driver role required.');
    });

    it('should reject user with no role in Firestore', async () => {
      const request = createRequest({ uid: 'nobody' });
      setRoleResolver(createMockResolver({ nobody: null }));
      
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Driver role required.');
    });
  });

  describe('requirePassenger', () => {
    it('should allow passenger user via token claims and return UID', async () => {
      const request = createRequest({
        uid: 'passenger123',
        token: { role: 'passenger' },
      });
      
      const uid = await requirePassenger(request);
      expect(uid).toBe('passenger123');
    });

    it('should allow passenger user via Firestore role and return UID', async () => {
      const request = createRequest({ uid: 'passenger456' });
      setRoleResolver(createMockResolver({ passenger456: 'passenger' }));
      
      const uid = await requirePassenger(request);
      expect(uid).toBe('passenger456');
    });

    it('should reject unauthenticated user', async () => {
      const request = createRequest();
      
      await expect(requirePassenger(request)).rejects.toThrow(HttpsError);
      await expect(requirePassenger(request)).rejects.toThrow('Login required.');
    });

    it('should reject driver user via token claims', async () => {
      const request = createRequest({
        uid: 'driver123',
        token: { role: 'driver' },
      });
      setRoleResolver(createMockResolver({ driver123: 'driver' }));
      
      await expect(requirePassenger(request)).rejects.toThrow(HttpsError);
      await expect(requirePassenger(request)).rejects.toThrow('Passenger role required.');
    });

    it('should reject admin user via token claims', async () => {
      const request = createRequest({
        uid: 'admin123',
        token: { role: 'admin' },
      });
      setRoleResolver(createMockResolver({ admin123: 'admin' }));
      
      await expect(requirePassenger(request)).rejects.toThrow(HttpsError);
      await expect(requirePassenger(request)).rejects.toThrow('Passenger role required.');
    });
  });

  describe('readUserRole', () => {
    it('should return role for valid admin user', async () => {
      setRoleResolver(createMockResolver({ admin123: 'admin' }));
      
      const role = await readUserRole('admin123');
      expect(role).toBe('admin');
    });

    it('should return role for valid driver user', async () => {
      setRoleResolver(createMockResolver({ driver123: 'driver' }));
      
      const role = await readUserRole('driver123');
      expect(role).toBe('driver');
    });

    it('should return role for valid passenger user', async () => {
      setRoleResolver(createMockResolver({ passenger123: 'passenger' }));
      
      const role = await readUserRole('passenger123');
      expect(role).toBe('passenger');
    });

    it('should return null for unknown role', async () => {
      setRoleResolver(createMockResolver({ nobody: null }));
      
      const role = await readUserRole('nobody');
      expect(role).toBeNull();
    });

    it('should return null for user with no role', async () => {
      setRoleResolver(createMockResolver({ nobody: null }));
      
      const role = await readUserRole('nobody');
      expect(role).toBeNull();
    });
  });

  describe('Token claims priority over Firestore', () => {
    it('should prioritize token claims for admin role', async () => {
      // Token says admin, Firestore says driver
      const request = createRequest({
        uid: 'driver123',
        token: { role: 'admin' },
      });
      setRoleResolver(createMockResolver({ driver123: 'driver' }));
      
      // requireAdmin should pass because token claims admin
      await expect(requireAdmin(request)).resolves.not.toThrow();
    });

    it('should prioritize token claims for driver role', async () => {
      // Token says driver, Firestore says passenger
      const request = createRequest({
        uid: 'passenger123',
        token: { role: 'driver' },
      });
      setRoleResolver(createMockResolver({ passenger123: 'passenger' }));
      
      // requireDriver should pass because token claims driver
      const uid = await requireDriver(request);
      expect(uid).toBe('passenger123');
    });
  });
});

describe('Backend Cloud Functions Role Enforcement Tests', () => {
  beforeEach(() => {
    resetRoleResolver();
  });

  afterEach(() => {
    resetRoleResolver();
  });

  describe('opsCancelRide role enforcement', () => {
    it('should reject unauthenticated user trying to call opsCancelRide', async () => {
      const request = createRequest();
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Login required.');
    });

    it('should reject passenger trying to call opsCancelRide', async () => {
      const request = createRequest({ uid: 'passenger123', token: { role: 'passenger' } });
      setRoleResolver(createMockResolver({ passenger123: 'passenger' }));
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Admin role required.');
    });

    it('should reject driver trying to call opsCancelRide', async () => {
      const request = createRequest({ uid: 'driver123', token: { role: 'driver' } });
      setRoleResolver(createMockResolver({ driver123: 'driver' }));
      await expect(requireAdmin(request)).rejects.toThrow(HttpsError);
      await expect(requireAdmin(request)).rejects.toThrow('Admin role required.');
    });

    it('should allow admin to call opsCancelRide', async () => {
      const request = createRequest({ uid: 'admin123', token: { role: 'admin' } });
      await expect(requireAdmin(request)).resolves.not.toThrow();
    });
  });

  describe('driver-only callables role enforcement', () => {
    it('should reject unauthenticated user trying to call driver-only callable', async () => {
      const request = createRequest();
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Login required.');
    });

    it('should reject passenger trying to call driver-only callable', async () => {
      const request = createRequest({ uid: 'passenger123', token: { role: 'passenger' } });
      setRoleResolver(createMockResolver({ passenger123: 'passenger' }));
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Driver role required.');
    });

    it('should allow driver to call driver-only callable', async () => {
      const request = createRequest({ uid: 'driver123', token: { role: 'driver' } });
      const uid = await requireDriver(request);
      expect(uid).toBe('driver123');
    });

    it('should reject admin trying to call driver-only callable', async () => {
      const request = createRequest({ uid: 'admin123', token: { role: 'admin' } });
      setRoleResolver(createMockResolver({ admin123: 'admin' }));
      await expect(requireDriver(request)).rejects.toThrow(HttpsError);
      await expect(requireDriver(request)).rejects.toThrow('Driver role required.');
    });
  });
});