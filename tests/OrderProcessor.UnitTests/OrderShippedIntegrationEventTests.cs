using eShop.OrderProcessor.Events;

namespace eShop.OrderProcessor.UnitTests;

[TestClass]
public class OrderShippedIntegrationEventTests
{
    [TestMethod]
    public void Constructor_sets_OrderId_and_BuyerIdentityGuid()
    {
        // Arrange
        var orderId = 42;
        var buyerIdentityGuid = "buyer-guid-123";

        // Act
        var @event = new OrderShippedIntegrationEvent(orderId, buyerIdentityGuid);

        // Assert
        Assert.AreEqual(orderId, @event.OrderId);
        Assert.AreEqual(buyerIdentityGuid, @event.BuyerIdentityGuid);
    }

    [TestMethod]
    public void Constructor_generates_unique_Id()
    {
        // Act
        var event1 = new OrderShippedIntegrationEvent(1, "buyer-1");
        var event2 = new OrderShippedIntegrationEvent(2, "buyer-2");

        // Assert
        Assert.AreNotEqual(Guid.Empty, event1.Id);
        Assert.AreNotEqual(Guid.Empty, event2.Id);
        Assert.AreNotEqual(event1.Id, event2.Id);
    }

    [TestMethod]
    public void Constructor_sets_CreationDate_to_recent_utc()
    {
        // Arrange
        var before = DateTime.UtcNow;

        // Act
        var @event = new OrderShippedIntegrationEvent(1, "buyer-1");

        // Assert
        var after = DateTime.UtcNow;
        Assert.IsTrue(@event.CreationDate >= before);
        Assert.IsTrue(@event.CreationDate <= after);
    }
}
