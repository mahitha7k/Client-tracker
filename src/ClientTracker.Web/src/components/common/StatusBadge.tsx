import type { EngagementStatus } from '../../types/client';

const STATUS_STYLES: Record<EngagementStatus, string> = {
  Planned: 'bg-slate-100 text-slate-700',
  Active: 'bg-emerald-100 text-emerald-700',
  OnHold: 'bg-amber-100 text-amber-700',
  Closed: 'bg-gray-200 text-gray-600',
};

export function StatusBadge({ status }: { status: EngagementStatus }) {
  return (
    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${STATUS_STYLES[status]}`}>
      {status}
    </span>
  );
}
