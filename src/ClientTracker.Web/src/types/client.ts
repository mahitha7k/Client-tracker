export type EngagementStatus = 'Planned' | 'Active' | 'OnHold' | 'Closed';

export interface Engagement {
  id: number;
  title: string;
  status: EngagementStatus;
  startDate: string | null;
  endDate: string | null;
  ownerEmail: string | null;
}

export interface ClientWithEngagements {
  id: number;
  name: string;
  industry: string | null;
  createdAt: string;
  engagements: Engagement[];
}
