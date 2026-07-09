using ClientTracker.Api.Data;
using ClientTracker.Api.Entities;
using Dapper;

namespace ClientTracker.Api.Repositories;

public class RiskRepository : IRiskRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public RiskRepository(IDbConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    private const string SelectColumns = """
        SELECT
            id             AS Id,
            engagement_id  AS EngagementId,
            description    AS Description,
            severity       AS Severity,
            logged_at      AS LoggedAt
        FROM risks
        """;

    public async Task<IEnumerable<Risk>> GetByEngagementIdAsync(int engagementId)
    {
        string sql = $"{SelectColumns} WHERE engagement_id = @EngagementId;";

        using var connection = await _connectionFactory.CreateConnectionAsync();
        return await connection.QueryAsync<Risk>(sql, new { EngagementId = engagementId });
    }

    public async Task<IEnumerable<Risk>> GetByEngagementIdsAsync(IEnumerable<int> engagementIds)
    {
        string sql = $"{SelectColumns} WHERE engagement_id IN @EngagementIds;";

        using var connection = await _connectionFactory.CreateConnectionAsync();
        return await connection.QueryAsync<Risk>(sql, new { EngagementIds = engagementIds });
    }
}
