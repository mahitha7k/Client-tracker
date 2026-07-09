namespace ClientTracker.Api.Dtos;

public class ClientWithEngagementsDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Industry { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<EngagementDto> Engagements { get; set; } = new();
}
