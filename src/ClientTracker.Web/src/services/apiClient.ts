import { InteractionRequiredAuthError } from '@azure/msal-browser';
import { ensureMsalInitialized, msalInstance } from '../auth/msalInstance';
import { apiRequest } from '../auth/msalConfig';

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'https://localhost:7000';

export class ApiError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

async function getAccessToken(): Promise<string> {
  await ensureMsalInitialized();
  const account = msalInstance.getActiveAccount() ?? msalInstance.getAllAccounts()[0];
  if (!account) {
    throw new Error('No signed-in account; user must log in first.');
  }

  try {
    const result = await msalInstance.acquireTokenSilent({ ...apiRequest, account });
    return result.accessToken;
  } catch (error) {
    if (error instanceof InteractionRequiredAuthError) {
      // Navigates away to sign in again; nothing after this executes on this pass.
      await msalInstance.acquireTokenRedirect({ ...apiRequest, account });
    }
    throw error;
  }
}

export async function apiGet<T>(path: string): Promise<T> {
  const token = await getAccessToken();

  const response = await fetch(`${BASE_URL}${path}`, {
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new ApiError(`Request to ${path} failed with status ${response.status}`, response.status);
  }

  return (await response.json()) as T;
}
