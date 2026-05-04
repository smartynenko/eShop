using eShop.OrderProcessor.Events;

namespace eShop.OrderProcessor.FunctionalTests;

public sealed class OrderShippedManagerServiceTests : IClassFixture<OrderProcessorFixture>
{
    private readonly OrderProcessorFixture _fixture;

    public OrderShippedManagerServiceTests(OrderProcessorFixture fixture)
    {
        _fixture = fixture;
        // Force the WebApplicationFactory host to start (it starts lazily on first request)
        _fixture.CreateClient();
    }

    [Fact]
    public async Task Publishes_event_for_shipped_order()
    {
        // Arrange
        await _fixture.InsertOrderAsync(orderId: 1001, status: "Shipped", buyerId: 1, buyerIdentityGuid: "buyer-guid-abc", buyerName: "Test Buyer");

        // Act — wait for the background service to pick up the order
        await WaitForEventAsync<OrderShippedIntegrationEvent>(
            e => e.OrderId == 1001,
            timeout: TimeSpan.FromSeconds(30));

        // Assert
        var shippedEvents = _fixture.EventBus.PublishedEvents
            .OfType<OrderShippedIntegrationEvent>()
            .Where(e => e.OrderId == 1001)
            .ToList();

        Assert.NotEmpty(shippedEvents);
        Assert.Equal("buyer-guid-abc", shippedEvents.First().BuyerIdentityGuid);
    }

    [Fact]
    public async Task Does_not_publish_event_for_non_shipped_order()
    {
        // Arrange
        await _fixture.InsertOrderAsync(orderId: 2001, status: "Paid", buyerId: 2, buyerIdentityGuid: "buyer-guid-def", buyerName: "Paid Buyer");

        // Act — wait a few polling cycles
        await Task.Delay(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken);

        // Assert
        var shippedEvents = _fixture.EventBus.PublishedEvents
            .OfType<OrderShippedIntegrationEvent>()
            .Where(e => e.OrderId == 2001)
            .ToList();

        Assert.Empty(shippedEvents);
    }

    private async Task WaitForEventAsync<T>(Func<T, bool> predicate, TimeSpan timeout) where T : class
    {
        using var cts = new CancellationTokenSource(timeout);
        while (!cts.Token.IsCancellationRequested)
        {
            if (_fixture.EventBus.PublishedEvents.OfType<T>().Any(predicate))
            {
                return;
            }
            await Task.Delay(TimeSpan.FromMilliseconds(250), cts.Token);
        }
    }
}
