import { useEffect, useState } from 'react';
import { getClients } from '../services/clientService';
import type { ClientWithEngagements } from '../types/client';

interface UseClientsResult {
  clients: ClientWithEngagements[];
  loading: boolean;
  error: string | null;
}

export function useClients(): UseClientsResult {
  const [clients, setClients] = useState<ClientWithEngagements[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    setLoading(true);
    setError(null);

    getClients()
      .then((data) => {
        if (!cancelled) {
          setClients(data);
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Failed to load clients');
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return { clients, loading, error };
}
