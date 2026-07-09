namespace ClientTracker.Api.Entities;

public enum RiskSeverity
{
    Low,
    Medium,
    High,
    Critical
}

public class Risk
{
    public int Id { get; set; }
    public int EngagementId { get; set; }
    public string Description { get; set; } = string.Empty;
    public RiskSeverity Severity { get; set; }
    public DateTime LoggedAt { get; set; }
}
