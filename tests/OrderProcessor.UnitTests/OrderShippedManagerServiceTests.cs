using eShop.EventBus.Abstractions;
using eShop.OrderProcessor.Events;
using eShop.OrderProcessor.Services;
using Microsoft.Extensions.Options;
using Npgsql;

namespace eShop.OrderProcessor.UnitTests;

[TestClass]
public class OrderShippedManagerServiceTests
{
    private readonly IEventBus _eventBusMock;
    private readonly ILogger<OrderShippedManagerService> _loggerMock;
    private readonly NpgsqlDataSource _dataSource;

    public OrderShippedManagerServiceTests()
    {
        _eventBusMock = Substitute.For<IEventBus>();
        _loggerMock = Substitute.For<ILogger<OrderShippedManagerService>>();
        _dataSource = NpgsqlDataSource.Create("Host=invalid_host;Database=fake");
    }

    [TestMethod]
    public async Task Does_not_publish_events_when_database_is_unavailable()
    {
        // Arrange
        var options = Options.Create(new BackgroundTaskOptions { CheckUpdateTime = 1 });
        var service = new OrderShippedManagerService(options, _eventBusMock, _loggerMock, _dataSource);

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));

        // Act
        await service.StartAsync(cts.Token);
        await Task.Delay(TimeSpan.FromSeconds(2), cts.Token);
        await service.StopAsync(CancellationToken.None);

        // Assert
        await _eventBusMock.DidNotReceive().PublishAsync(Arg.Any<OrderShippedIntegrationEvent>());
    }

    [TestMethod]
    public void Throws_when_options_is_null()
    {
        // Assert
        Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderShippedManagerService(null, _eventBusMock, _loggerMock, _dataSource));
    }
}
