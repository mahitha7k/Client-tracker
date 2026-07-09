import type { ClientWithEngagements } from '../types/client';
import { EngagementList } from './EngagementList';

export function ClientCard({ client }: { client: ClientWithEngagements }) {
  return (
    <article className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
      <header className="mb-3 flex items-start justify-between">
        <div>
          <h2 className="text-lg font-semibold text-slate-900">{client.name}</h2>
          {client.industry && <p className="text-sm text-slate-500">{client.industry}</p>}
        </div>
        <span className="text-xs text-slate-400">
          {client.engagements.length} engagement{client.engagements.length === 1 ? '' : 's'}
        </span>
      </header>
      <EngagementList engagements={client.engagements} />
    </article>
  );
}
