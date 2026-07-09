import type { Engagement } from '../types/client';
import { StatusBadge } from './common/StatusBadge';

function formatDate(value: string | null): string {
  if (!value) return '—';
  return new Date(value).toLocaleDateString();
}

export function EngagementList({ engagements }: { engagements: Engagement[] }) {
  if (engagements.length === 0) {
    return <p className="text-sm text-slate-400">No engagements yet.</p>;
  }

  return (
    <ul className="divide-y divide-slate-100">
      {engagements.map((engagement) => (
        <li key={engagement.id} className="flex items-center justify-between gap-4 py-2">
          <div>
            <p className="font-medium text-slate-800">{engagement.title}</p>
            <p className="text-xs text-slate-500">
              {formatDate(engagement.startDate)} – {formatDate(engagement.endDate)}
              {engagement.ownerEmail && <span> · {engagement.ownerEmail}</span>}
            </p>
          </div>
          <StatusBadge status={engagement.status} />
        </li>
      ))}
    </ul>
  );
}
