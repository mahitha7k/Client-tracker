using ClientTracker.Api.Dtos;
using ClientTracker.Api.Entities;
using ClientTracker.Api.Repositories;

namespace ClientTracker.Api.Services;

public class ClientService : IClientService
{
    private readonly IClientRepository _clientRepository;
    private readonly IEngagementRepository _engagementRepository;

    public ClientService(IClientRepository clientRepository, IEngagementRepository engagementRepository)
    {
        _clientRepository = clientRepository;
        _engagementRepository = engagementRepository;
    }

    public async Task<IEnumerable<ClientWithEngagementsDto>> GetAllClientsWithEngagementsAsync()
    {
        var clients = (await _clientRepository.GetAllAsync()).ToList();
        var clientIds = clients.Select(c => c.Id);
        var engagementsByClientId = (await _engagementRepository.GetByClientIdsAsync(clientIds))
            .ToLookup(e => e.ClientId);

        return clients.Select(c => new ClientWithEngagementsDto
        {
            Id = c.Id,
            Name = c.Name,
            Industry = c.Industry,
            CreatedAt = c.CreatedAt,
            Engagements = engagementsByClientId[c.Id].Select(MapEngagement).ToList()
        });
    }

    public async Task<ClientWithEngagementsDto?> GetClientWithEngagementsByIdAsync(int id)
    {
        var client = await _clientRepository.GetByIdAsync(id);
        if (client is null)
        {
            return null;
        }

        var engagements = await _engagementRepository.GetByClientIdAsync(id);

        return new ClientWithEngagementsDto
        {
            Id = client.Id,
            Name = client.Name,
            Industry = client.Industry,
            CreatedAt = client.CreatedAt,
            Engagements = engagements.Select(MapEngagement).ToList()
        };
    }

    private static EngagementDto MapEngagement(Engagement e) => new()
    {
        Id = e.Id,
        Title = e.Title,
        Status = e.Status,
        StartDate = e.StartDate,
        EndDate = e.EndDate,
        OwnerEmail = e.OwnerEmail
    };
}
