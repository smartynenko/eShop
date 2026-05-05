namespace eShop.Catalog.API.IntegrationEvents.EventHandling;

public class OrderStatusChangedToPaidIntegrationEventHandler(
    CatalogContext catalogContext,
    ILogger<OrderStatusChangedToPaidIntegrationEventHandler> logger) :
    IIntegrationEventHandler<OrderStatusChangedToPaidIntegrationEvent>
{
    private const int MaxItemsForPairing = 10;

    public async Task Handle(OrderStatusChangedToPaidIntegrationEvent @event)
    {
        logger.LogInformation("Handling integration event: {IntegrationEventId} - ({@IntegrationEvent})", @event.Id, @event);

        //we're not blocking stock/inventory
        foreach (var orderStockItem in @event.OrderStockItems)
        {
            var catalogItem = catalogContext.CatalogItems.Find(orderStockItem.ProductId);

            catalogItem?.RemoveStock(orderStockItem.Units);
        }

        await UpdateCoPurchaseAssociations(@event.OrderStockItems);

        await catalogContext.SaveChangesAsync();
    }

    private async Task UpdateCoPurchaseAssociations(IEnumerable<OrderStockItem> orderStockItems)
    {
        var productIds = orderStockItems
            .Select(s => s.ProductId)
            .Distinct()
            .Take(MaxItemsForPairing)
            .ToList();

        if (productIds.Count < 2)
        {
            return;
        }

        var now = DateTime.UtcNow;

        for (var i = 0; i < productIds.Count; i++)
        {
            for (var j = i + 1; j < productIds.Count; j++)
            {
                await UpsertAssociation(productIds[i], productIds[j], now);
                await UpsertAssociation(productIds[j], productIds[i], now);
            }
        }
    }

    private async Task UpsertAssociation(int catalogItemId, int relatedCatalogItemId, DateTime now)
    {
        var association = await catalogContext.CatalogItemAssociations
            .FindAsync(catalogItemId, relatedCatalogItemId);

        if (association is null)
        {
            catalogContext.CatalogItemAssociations.Add(new CatalogItemAssociation
            {
                CatalogItemId = catalogItemId,
                RelatedCatalogItemId = relatedCatalogItemId,
                OrderCount = 1,
                LastUpdated = now
            });
        }
        else
        {
            association.OrderCount++;
            association.LastUpdated = now;
        }
    }
}
