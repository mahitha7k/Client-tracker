namespace ClientTracker.Api.Entities;

public enum EngagementStatus
{
    Planned,
    Active,
    OnHold,
    Closed
}

public class Engagement
{
    public int Id { get; set; }
    public int ClientId { get; set; }
    public string Title { get; set; } = string.Empty;
    public EngagementStatus Status { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? OwnerEmail { get; set; }
}
