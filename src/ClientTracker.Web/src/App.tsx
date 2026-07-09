import { AuthProvider } from './auth/AuthContext';
import { RequireAuth } from './auth/RequireAuth';
import { LoginPage } from './auth/LoginPage';
import { useAuth } from './auth/useAuth';
import { ClientList } from './components/ClientList';

function AppContent() {
  const { isAuthenticated } = useAuth();

  if (!isAuthenticated) {
    return <LoginPage />;
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto max-w-4xl px-6 py-4">
          <h1 className="text-xl font-semibold text-slate-900">Client Engagement Tracker</h1>
        </div>
      </header>
      <main className="mx-auto max-w-4xl px-6 py-8">
        <RequireAuth>
          <ClientList />
        </RequireAuth>
      </main>
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
