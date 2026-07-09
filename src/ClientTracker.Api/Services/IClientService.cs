using ClientTracker.Api.Dtos;

namespace ClientTracker.Api.Services;

public interface IClientService
{
    Task<IEnumerable<ClientWithEngagementsDto>> GetAllClientsWithEngagementsAsync();
    Task<ClientWithEngagementsDto?> GetClientWithEngagementsByIdAsync(int id);
}
