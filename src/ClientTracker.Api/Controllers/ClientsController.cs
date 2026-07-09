using ClientTracker.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Web.Resource;

namespace ClientTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
[RequiredScope("access_as_user")]
public class ClientsController : ControllerBase
{
    private readonly IClientService _clientService;

    public ClientsController(IClientService clientService)
    {
        _clientService = clientService;
    }

    // GET /api/clients
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var clients = await _clientService.GetAllClientsWithEngagementsAsync();
        return Ok(clients);
    }

    // GET /api/clients/5
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var client = await _clientService.GetClientWithEngagementsByIdAsync(id);
        return client is null ? NotFound() : Ok(client);
    }
}
