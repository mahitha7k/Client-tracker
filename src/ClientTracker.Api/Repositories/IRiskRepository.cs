using ClientTracker.Api.Entities;

namespace ClientTracker.Api.Repositories;

public interface IRiskRepository
{
    Task<IEnumerable<Risk>> GetByEngagementIdAsync(int engagementId);
    Task<IEnumerable<Risk>> GetByEngagementIdsAsync(IEnumerable<int> engagementIds);
}
