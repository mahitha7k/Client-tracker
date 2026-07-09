import { PublicClientApplication, EventType, type AccountInfo } from '@azure/msal-browser';
import { msalConfig } from './msalConfig';

export const msalInstance = new PublicClientApplication(msalConfig);

// Keep MSAL's "active account" in sync so acquireTokenSilent (called from
// apiClient.ts, outside React) always knows which account to use.
msalInstance.addEventCallback((event) => {
  const isAccountEvent =
    event.eventType === EventType.LOGIN_SUCCESS || event.eventType === EventType.ACQUIRE_TOKEN_SUCCESS;

  if (isAccountEvent && event.payload && 'account' in event.payload && event.payload.account) {
    msalInstance.setActiveAccount(event.payload.account as AccountInfo);
  }
});

let initialized: Promise<void> | null = null;

export function ensureMsalInitialized(): Promise<void> {
  if (!initialized) {
    initialized = msalInstance.initialize().then(() => {
      const account = msalInstance.getActiveAccount() ?? msalInstance.getAllAccounts()[0];
      if (account) {
        msalInstance.setActiveAccount(account);
      }
    });
  }
  return initialized;
}
