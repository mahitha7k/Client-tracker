# Client Engagement Tracker

A full-stack app for tracking client engagements and risks, secured with Azure AD (Entra ID) and deployable to Azure Container Apps.

## Stack

- **API**: ASP.NET Core 8, Controllers, Dapper + MySqlConnector (repository pattern), Microsoft.Identity.Web for bearer-token auth
- **Web**: React 19 + TypeScript + Vite, Tailwind CSS v4, MSAL.js (`@azure/msal-browser` + `@azure/msal-react`)
- **Database**: MySQL (Azure Database for MySQL Flexible Server in production)
- **Auth**: Azure AD, single-tenant, OAuth 2.0 Authorization Code + PKCE, two app registrations (API resource + SPA client)
- **Deployment**: Docker containers on Azure Container Apps, images built via Azure Container Registry, provisioned with Azure CLI PowerShell scripts

## Repo layout

```
ClientTracker.sln
scripts.txt                                    MySQL DDL + seed data
scripts/
  create-azure-ad-app-registrations.ps1         Creates the two Azure AD app registrations
  deploy-infrastructure.ps1                     One-time Azure infra provisioning
  deploy-apps.ps1                                Builds + deploys both container images (repeatable)
docs/
  demo-runbook.html                              Talk-through script for demoing the app
src/
  ClientTracker.Api/                             .NET 8 Web API
  ClientTracker.Web/                              React + Vite SPA
```

## Local development

### Prerequisites
- .NET 8 SDK
- Node.js 20+
- A local MySQL server
- Azure CLI, logged in (`az login`), for the Azure AD script

### 1. Database
Run `scripts.txt` against your local MySQL server to create and seed the `engagement_tracker` database.

### 2. Azure AD app registrations
```powershell
powershell -ExecutionPolicy Bypass -File scripts/create-azure-ad-app-registrations.ps1
```
Copy the printed values into:
- `src/ClientTracker.Api/appsettings.Development.json` (create it, or copy the shape from `appsettings.json`) — `ConnectionStrings:EngagementTracker` (your local MySQL password) and the `AzureAd` section
- `src/ClientTracker.Web/.env` (copy `.env.example`) — `VITE_AZURE_CLIENT_ID`, `VITE_AZURE_TENANT_ID`, `VITE_API_SCOPE`

Both files are gitignored since they hold environment-specific values.

### 3. HTTPS dev certificate (for the frontend)
```bash
dotnet dev-certs https --export-path src/ClientTracker.Web/.cert/localhost.pem --format Pem -np
```

### 4. Run both apps
```powershell
dotnet run --project src/ClientTracker.Api --launch-profile https
```
```bash
cd src/ClientTracker.Web && npm install && npm run dev
```
Visit `https://localhost:5173`.

## Deploying to Azure

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy-infrastructure.ps1   # one-time
powershell -ExecutionPolicy Bypass -File scripts/deploy-apps.ps1             # every deploy
```

See `docs/demo-runbook.html` for a walkthrough of the deployed app, including the security model and a live-demo script.
