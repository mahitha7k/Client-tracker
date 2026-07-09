namespace ClientTracker.Api.Entities;

public class Client
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Industry { get; set; }
    public DateTime CreatedAt { get; set; }
}
