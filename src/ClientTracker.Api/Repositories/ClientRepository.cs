using ClientTracker.Api.Data;
using ClientTracker.Api.Entities;
using Dapper;

namespace ClientTracker.Api.Repositories;

public class ClientRepository : IClientRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public ClientRepository(IDbConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IEnumerable<Client>> GetAllAsync()
    {
        const string sql = """
            SELECT
                id          AS Id,
                name        AS Name,
                industry    AS Industry,
                created_at  AS CreatedAt
            FROM clients
            ORDER BY name;
            """;

        using var connection = await _connectionFactory.CreateConnectionAsync();
        return await connection.QueryAsync<Client>(sql);
    }

    public async Task<Client?> GetByIdAsync(int id)
    {
        const string sql = """
            SELECT
                id          AS Id,
                name        AS Name,
                industry    AS Industry,
                created_at  AS CreatedAt
            FROM clients
            WHERE id = @Id;
            """;

        using var connection = await _connectionFactory.CreateConnectionAsync();
        return await connection.QuerySingleOrDefaultAsync<Client>(sql, new { Id = id });
    }
}
