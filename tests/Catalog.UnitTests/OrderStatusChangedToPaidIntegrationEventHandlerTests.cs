using eShop.Catalog.API.Infrastructure;
using eShop.Catalog.API.IntegrationEvents.EventHandling;
using eShop.Catalog.API.IntegrationEvents.Events;
using eShop.Catalog.API.Model;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;

namespace eShop.Catalog.UnitTests;

[TestClass]
public class OrderStatusChangedToPaidIntegrationEventHandlerTests
{
    private static TestCatalogContext CreateDbContext(string dbName)
    {
        var options = new DbContextOptionsBuilder<CatalogContext>()
            .UseInMemoryDatabase(dbName)
            .Options;

        var configuration = new ConfigurationBuilder().Build();
        return new TestCatalogContext(options, configuration);
    }

    [TestMethod]
    public async Task Handle_creates_associations_for_multi_item_order()
    {
        using var context = CreateDbContext(nameof(Handle_creates_associations_for_multi_item_order));
        context.CatalogItems.AddRange(
            new CatalogItem("Item A") { Id = 1, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 },
            new CatalogItem("Item B") { Id = 2, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 },
            new CatalogItem("Item C") { Id = 3, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 }
        );
        await context.SaveChangesAsync();

        var handler = new OrderStatusChangedToPaidIntegrationEventHandler(
            context,
            NullLogger<OrderStatusChangedToPaidIntegrationEventHandler>.Instance);

        var @event = new OrderStatusChangedToPaidIntegrationEvent(1, [
            new OrderStockItem(1, 1),
            new OrderStockItem(2, 1),
            new OrderStockItem(3, 1)
        ]);

        await handler.Handle(@event);

        var associations = await context.CatalogItemAssociations.ToListAsync();
        // 3 items = 3 pairs, each stored bidirectionally = 6 records
        Assert.AreEqual(6, associations.Count);
        Assert.IsTrue(associations.All(a => a.OrderCount == 1));
    }

    [TestMethod]
    public async Task Handle_increments_order_count_for_existing_associations()
    {
        using var context = CreateDbContext(nameof(Handle_increments_order_count_for_existing_associations));
        context.CatalogItems.AddRange(
            new CatalogItem("Item A") { Id = 1, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 },
            new CatalogItem("Item B") { Id = 2, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 }
        );
        context.CatalogItemAssociations.AddRange(
            new CatalogItemAssociation { CatalogItemId = 1, RelatedCatalogItemId = 2, OrderCount = 3, LastUpdated = DateTime.UtcNow },
            new CatalogItemAssociation { CatalogItemId = 2, RelatedCatalogItemId = 1, OrderCount = 3, LastUpdated = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var handler = new OrderStatusChangedToPaidIntegrationEventHandler(
            context,
            NullLogger<OrderStatusChangedToPaidIntegrationEventHandler>.Instance);

        var @event = new OrderStatusChangedToPaidIntegrationEvent(2, [
            new OrderStockItem(1, 1),
            new OrderStockItem(2, 1)
        ]);

        await handler.Handle(@event);

        var associations = await context.CatalogItemAssociations.ToListAsync();
        Assert.AreEqual(2, associations.Count);
        Assert.IsTrue(associations.All(a => a.OrderCount == 4));
    }

    [TestMethod]
    public async Task Handle_does_not_create_associations_for_single_item_order()
    {
        using var context = CreateDbContext(nameof(Handle_does_not_create_associations_for_single_item_order));
        context.CatalogItems.Add(
            new CatalogItem("Item A") { Id = 1, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 }
        );
        await context.SaveChangesAsync();

        var handler = new OrderStatusChangedToPaidIntegrationEventHandler(
            context,
            NullLogger<OrderStatusChangedToPaidIntegrationEventHandler>.Instance);

        var @event = new OrderStatusChangedToPaidIntegrationEvent(1, [
            new OrderStockItem(1, 5)
        ]);

        await handler.Handle(@event);

        var associations = await context.CatalogItemAssociations.ToListAsync();
        Assert.AreEqual(0, associations.Count);
    }

    [TestMethod]
    public async Task Handle_deduplicates_product_ids_in_order()
    {
        using var context = CreateDbContext(nameof(Handle_deduplicates_product_ids_in_order));
        context.CatalogItems.AddRange(
            new CatalogItem("Item A") { Id = 1, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 },
            new CatalogItem("Item B") { Id = 2, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 }
        );
        await context.SaveChangesAsync();

        var handler = new OrderStatusChangedToPaidIntegrationEventHandler(
            context,
            NullLogger<OrderStatusChangedToPaidIntegrationEventHandler>.Instance);

        var @event = new OrderStatusChangedToPaidIntegrationEvent(1, [
            new OrderStockItem(1, 1),
            new OrderStockItem(1, 2),
            new OrderStockItem(2, 1)
        ]);

        await handler.Handle(@event);

        var associations = await context.CatalogItemAssociations.ToListAsync();
        // Only 1 unique pair (1,2) stored bidirectionally = 2 records
        Assert.AreEqual(2, associations.Count);
    }

    [TestMethod]
    public async Task Handle_caps_pairing_at_10_items()
    {
        using var context = CreateDbContext(nameof(Handle_caps_pairing_at_10_items));
        for (var i = 1; i <= 12; i++)
        {
            context.CatalogItems.Add(new CatalogItem($"Item {i}") { Id = i, CatalogBrandId = 1, CatalogTypeId = 1, AvailableStock = 100 });
        }
        await context.SaveChangesAsync();

        var handler = new OrderStatusChangedToPaidIntegrationEventHandler(
            context,
            NullLogger<OrderStatusChangedToPaidIntegrationEventHandler>.Instance);

        var stockItems = Enumerable.Range(1, 12).Select(i => new OrderStockItem(i, 1));
        var @event = new OrderStatusChangedToPaidIntegrationEvent(1, stockItems);

        await handler.Handle(@event);

        var associations = await context.CatalogItemAssociations.ToListAsync();
        // 10 items capped = C(10,2) pairs * 2 directions = 45 * 2 = 90
        Assert.AreEqual(90, associations.Count);
    }
}
