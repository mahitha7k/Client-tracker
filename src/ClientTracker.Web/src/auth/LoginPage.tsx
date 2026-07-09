import { useAuth } from './useAuth';

export function LoginPage() {
  const { login } = useAuth();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-slate-50 px-6">
      <div className="w-full max-w-sm rounded-lg border border-slate-200 bg-white p-8 text-center shadow-sm">
        <h1 className="text-xl font-semibold text-slate-900">Client Engagement Tracker</h1>
        <p className="mt-2 text-sm text-slate-500">Sign in with your organization account to continue.</p>
        <button
          type="button"
          onClick={login}
          className="mt-6 w-full rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700"
        >
          Sign in with Microsoft
        </button>
      </div>
    </div>
  );
}
