using ClientTracker.Api.Entities;

namespace ClientTracker.Api.Dtos;

public class EngagementDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public EngagementStatus Status { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? OwnerEmail { get; set; }
}
