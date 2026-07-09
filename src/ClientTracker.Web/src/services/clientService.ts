import { apiGet } from './apiClient';
import type { ClientWithEngagements } from '../types/client';

export function getClients(): Promise<ClientWithEngagements[]> {
  return apiGet<ClientWithEngagements[]>('/api/clients');
}

export function getClientById(id: number): Promise<ClientWithEngagements> {
  return apiGet<ClientWithEngagements>(`/api/clients/${id}`);
}
