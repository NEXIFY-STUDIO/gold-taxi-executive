import { HttpsError } from 'firebase-functions/v2/https';

type UserRole = 'admin' | 'driver' | 'passenger';

interface CallableRequest {
  auth?: {
    uid: string;
    token?: {
      role?: string;
      email?: string;
    };
  };
  data?: Record<string, unknown>;
}

/**
 * Mockable interface for role resolution from Firestore.
 * In production, this is implemented by reading from Firestore.
 * In tests, this can be mocked to return predefined roles.
 */
export interface RoleResolver {
  readUserRole: (uid: string) => Promise<UserRole | null>;
}

/**
 * Default production role resolver - reads from Firestore.
 * This is the real implementation used in production.
 */
let roleResolver: RoleResolver = {
  readUserRole: async (_uid: string): Promise<UserRole | null> => {
    // In the real implementation, this reads from Firestore
    // For testing, this will be overridden
    throw new Error('Role resolver not initialized for tests');
  },
};

/**
 * Set the role resolver for testing purposes.
 * This allows tests to inject mock role resolution.
 */
export function setRoleResolver(resolver: RoleResolver): void {
  roleResolver = resolver;
}

/**
 * Reset role resolver to default (useful for test cleanup).
 */
export function resetRoleResolver(): void {
  roleResolver = {
    readUserRole: async (_uid: string): Promise<UserRole | null> => {
      throw new Error('Role resolver not initialized for tests');
    },
  };
}

/**
 * Extract the UID from a callable request, throwing if unauthenticated.
 */
export function ensureAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Login required.');
  }
  return request.auth.uid as string;
}

/**
 * Read a user's role from the resolver (in production, from Firestore).
 * Exported for testing.
 */
export async function readUserRole(uid: string): Promise<UserRole | null> {
  const role = await roleResolver.readUserRole(uid);
  if (role === 'admin' || role === 'driver' || role === 'passenger') {
    return role;
  }
  return null;
}

/**
 * Require admin role on the request.
 * Checks token claims first (for performance), then falls back to Firestore.
 * Throws HttpsError with permission-denied if not admin.
 */
export async function requireAdmin(request: CallableRequest): Promise<void> {
  // Fast path: check token claims
  if (request.auth?.token?.role === 'admin') {
    return;
  }
  
  // Fallback: check Firestore
  const uid = ensureAuth(request);
  const role = await readUserRole(uid);
  if (role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin role required.');
  }
}

/**
 * Require driver role on the request.
 * Checks token claims first (for performance), then falls back to Firestore.
 * Returns the UID if successful.
 * Throws HttpsError with permission-denied if not driver.
 */
export async function requireDriver(request: CallableRequest): Promise<string> {
  // Fast path: check token claims
  if (request.auth?.token?.role === 'driver') {
    return ensureAuth(request);
  }
  
  // Fallback: check Firestore
  const uid = ensureAuth(request);
  const role = await readUserRole(uid);
  if (role !== 'driver') {
    throw new HttpsError('permission-denied', 'Driver role required.');
  }
  return uid;
}

/**
 * Require passenger role on the request.
 * Useful for passenger-only operations.
 */
export async function requirePassenger(request: CallableRequest): Promise<string> {
  // Fast path: check token claims
  if (request.auth?.token?.role === 'passenger') {
    return ensureAuth(request);
  }
  
  // Fallback: check Firestore
  const uid = ensureAuth(request);
  const role = await readUserRole(uid);
  if (role !== 'passenger') {
    throw new HttpsError('permission-denied', 'Passenger role required.');
  }
  return uid;
}

// Re-export types for convenience
export type { UserRole, CallableRequest };