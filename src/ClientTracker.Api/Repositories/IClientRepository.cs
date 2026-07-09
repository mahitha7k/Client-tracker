using ClientTracker.Api.Entities;

namespace ClientTracker.Api.Repositories;

public interface IClientRepository
{
    Task<IEnumerable<Client>> GetAllAsync();
    Task<Client?> GetByIdAsync(int id);
}
