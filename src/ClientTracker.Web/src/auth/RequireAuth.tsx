import type { ReactNode } from 'react';
import { useAuth } from './useAuth';

/**
 * Placeholder route guard: passes children through as long as the stub
 * AuthProvider reports a user. Swap the isAuthenticated check for a real
 * redirect-to-login once the API has an actual auth mechanism.
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth();

  if (!isAuthenticated) {
    return <p className="p-6 text-center text-slate-500">Please sign in to continue.</p>;
  }

  return <>{children}</>;
}
