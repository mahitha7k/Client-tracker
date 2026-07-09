import { useClients } from '../hooks/useClients';
import { ClientCard } from './ClientCard';
import { Spinner } from './common/Spinner';
import { ErrorMessage } from './common/ErrorMessage';

export function ClientList() {
  const { clients, loading, error } = useClients();

  if (loading) return <Spinner />;
  if (error) return <ErrorMessage message={error} />;
  if (clients.length === 0) {
    return <p className="text-center text-slate-500">No clients found.</p>;
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {clients.map((client) => (
        <ClientCard key={client.id} client={client} />
      ))}
    </div>
  );
}
