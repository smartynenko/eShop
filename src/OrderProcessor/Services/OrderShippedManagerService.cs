using eShop.EventBus.Abstractions;
using Microsoft.Extensions.Options;
using Npgsql;
using eShop.OrderProcessor.Events;

namespace eShop.OrderProcessor.Services
{
    public class OrderShippedManagerService(
        IOptions<BackgroundTaskOptions> options,
        IEventBus eventBus,
        ILogger<OrderShippedManagerService> logger,
        NpgsqlDataSource dataSource) : BackgroundService
    {
        private readonly BackgroundTaskOptions _options = options?.Value ?? throw new ArgumentNullException(nameof(options));

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var delayTime = TimeSpan.FromSeconds(_options.CheckUpdateTime);

            if (logger.IsEnabled(LogLevel.Debug))
            {
                logger.LogDebug("OrderShippedManagerService is starting.");
                stoppingToken.Register(() => logger.LogDebug("OrderShippedManagerService background task is stopping."));
            }

            while (!stoppingToken.IsCancellationRequested)
            {
                if (logger.IsEnabled(LogLevel.Debug))
                {
                    logger.LogDebug("OrderShippedManagerService background task is doing background work.");
                }

                await CheckShippedOrders();

                await Task.Delay(delayTime, stoppingToken);
            }

            if (logger.IsEnabled(LogLevel.Debug))
            {
                logger.LogDebug("OrderShippedManagerService background task is stopping.");
            }
        }

        private async Task CheckShippedOrders()
        {
            if (logger.IsEnabled(LogLevel.Debug))
            {
                logger.LogDebug("Checking shipped orders");
            }

            var shippedOrders = await GetShippedOrders();

            foreach (var (orderId, buyerIdentityGuid) in shippedOrders)
            {
                var orderShippedEvent = new OrderShippedIntegrationEvent(orderId, buyerIdentityGuid);

                logger.LogInformation("Publishing integration event: {IntegrationEventId} - ({@IntegrationEvent})", orderShippedEvent.Id, orderShippedEvent);

                await eventBus.PublishAsync(orderShippedEvent);
            }
        }

        private async ValueTask<List<(int OrderId, string BuyerIdentityGuid)>> GetShippedOrders()
        {
            try
            {
                using var conn = dataSource.CreateConnection();
                using var command = conn.CreateCommand();
                command.CommandText = """
                    SELECT o."Id", b."IdentityGuid"
                    FROM ordering.orders o
                    INNER JOIN ordering.buyers b ON o."BuyerId" = b."Id"
                    WHERE o."OrderStatus" = 'Shipped'
                    """;

                List<(int, string)> results = [];

                await conn.OpenAsync();
                using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    results.Add((reader.GetInt32(0), reader.GetString(1)));
                }

                return results;
            }
            catch (NpgsqlException exception)
            {
                logger.LogError(exception, "Fatal error establishing database connection");
            }

            return [];
        }
    }
}
