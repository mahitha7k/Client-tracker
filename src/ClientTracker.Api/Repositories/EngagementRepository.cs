using ClientTracker.Api.Data;
using ClientTracker.Api.Entities;
using Dapper;

namespace ClientTracker.Api.Repositories;

public class EngagementRepository : IEngagementRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public EngagementRepository(IDbConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    private const string SelectColumns = """
        SELECT
            id            AS Id,
            client_id     AS ClientId,
            title         AS Title,
            status        AS Status,
            start_date    AS StartDate,
            end_date      AS EndDate,
            owner_email   AS OwnerEmail
        FROM engagements
        """;

    public async Task<IEnumerable<Engagement>> GetAllAsync()
    {
        string sql = $"{SelectColumns};";

        using var connection = await _connectionFactory.CreateConnectionAsync();
        return await connection.QueryAsync<Engagement>(sql);
    }

    public async Task<IEnumerable<Engagement>> GetByClientIdAsync(int clientId)
    {
        string sql = $"{SelectColumns} WHERE client_id = @ClientId;";

        using var connection = await _connectionFactory.CreateConnectionAsync();
        return await connection.QueryAsync<Engagement>(sql, new { ClientId = clientId });
    }

    public async Task<IEnumerable<Engagement>> GetByClientIdsAsync(IEnumerable<int> clientIds)
    {
        string sql = $"{SelectColumns} WHERE client_id IN @ClientIds;";

        using var connection = await _connectionFactory.CreateConnectionAsync();
        return await connection.QueryAsync<Engagement>(sql, new { ClientIds = clientIds });
    }
}
