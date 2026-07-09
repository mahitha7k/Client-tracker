using System.Data;

namespace ClientTracker.Api.Data;

public interface IDbConnectionFactory
{
    Task<IDbConnection> CreateConnectionAsync();
}
