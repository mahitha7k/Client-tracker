import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { MsalProvider } from '@azure/msal-react'
import './index.css'
import App from './App.tsx'
import { ensureMsalInitialized, msalInstance } from './auth/msalInstance'

ensureMsalInitialized().then(() => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <MsalProvider instance={msalInstance}>
        <App />
      </MsalProvider>
    </StrictMode>,
  )
})
