namespace eShop.OrderProcessor.Events
{
    using eShop.EventBus.Events;

    public record OrderShippedIntegrationEvent : IntegrationEvent
    {
        public int OrderId { get; }

        public string BuyerIdentityGuid { get; }

        public OrderShippedIntegrationEvent(int orderId, string buyerIdentityGuid)
        {
            OrderId = orderId;
            BuyerIdentityGuid = buyerIdentityGuid;
        }
    }
}
