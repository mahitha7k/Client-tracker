using ClientTracker.Api.Entities;

namespace ClientTracker.Api.Repositories;

public interface IEngagementRepository
{
    Task<IEnumerable<Engagement>> GetAllAsync();
    Task<IEnumerable<Engagement>> GetByClientIdAsync(int clientId);
    Task<IEnumerable<Engagement>> GetByClientIdsAsync(IEnumerable<int> clientIds);
}
