import { createContext, useMemo, type ReactNode } from 'react';
import { useIsAuthenticated, useMsal } from '@azure/msal-react';
import { apiRequest } from './msalConfig';

export interface AuthUser {
  email: string;
  name: string;
}

export interface AuthContextValue {
  user: AuthUser | null;
  isAuthenticated: boolean;
  login: () => void;
  logout: () => void;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const isAuthenticated = useIsAuthenticated();
  const { instance, accounts } = useMsal();

  const value = useMemo<AuthContextValue>(() => {
    const account = accounts[0];

    return {
      user: account ? { email: account.username, name: account.name ?? account.username } : null,
      isAuthenticated,
      login: () => {
        void instance.loginRedirect(apiRequest);
      },
      logout: () => {
        void instance.logoutRedirect();
      },
    };
  }, [isAuthenticated, accounts, instance]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
