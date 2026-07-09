using System.Data;
using MySqlConnector;

namespace ClientTracker.Api.Data;

public class MySqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public MySqlConnectionFactory(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("EngagementTracker")
            ?? throw new InvalidOperationException("Connection string 'EngagementTracker' not found.");
    }

    public async Task<IDbConnection> CreateConnectionAsync()
    {
        var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync();
        return connection;
    }
}
