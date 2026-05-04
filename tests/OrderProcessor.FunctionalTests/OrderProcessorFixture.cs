using System.Collections.Concurrent;
using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using eShop.EventBus.Abstractions;
using eShop.EventBus.Events;
using eShop.EventBusRabbitMQ;
using Microsoft.AspNetCore.Mvc.Testing;
using Npgsql;

namespace eShop.OrderProcessor.FunctionalTests;

public sealed class OrderProcessorFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly IHost _app;

    public IResourceBuilder<PostgresServerResource> Postgres { get; private set; }
    private string _postgresConnectionString;

    public CapturingEventBus EventBus { get; } = new();

    public OrderProcessorFixture()
    {
        var options = new DistributedApplicationOptions { AssemblyName = typeof(OrderProcessorFixture).Assembly.FullName, DisableDashboard = true };
        var appBuilder = DistributedApplication.CreateBuilder(options);
        Postgres = appBuilder.AddPostgres("OrderingDB");
        _app = appBuilder.Build();
    }

    private string GetConnectionStringWithSslDisabled()
    {
        var connStringBuilder = new NpgsqlConnectionStringBuilder(_postgresConnectionString)
        {
            SslMode = SslMode.Disable
        };
        return connStringBuilder.ConnectionString;
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.ConfigureHostConfiguration(config =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string>
            {
                { "ConnectionStrings:orderingdb", GetConnectionStringWithSslDisabled() },
                { "ConnectionStrings:eventbus", "amqp://localhost" },
                { "Aspire:Npgsql:orderingdb:DisableHealthChecks", "true" },
                { "BackgroundTaskOptions:CheckUpdateTime", "1" },
                { "BackgroundTaskOptions:GracePeriodTime", "1" },
            });
        });
        builder.ConfigureServices(services =>
        {
            // Remove all RabbitMQ-related services.
            // The IHostedService for RabbitMQEventBus is registered via a factory lambda
            // that casts IEventBus to RabbitMQEventBus, so we must remove it to avoid InvalidCastException.
            var descriptorsToRemove = services
                .Where(d => d.ServiceType == typeof(IEventBus)
                          || d.ServiceType == typeof(RabbitMQTelemetry)
                          || d.ImplementationType == typeof(RabbitMQEventBus)
                          || (d.ServiceType == typeof(IHostedService) && d.ImplementationFactory is not null && d.Lifetime == ServiceLifetime.Singleton))
                .ToList();
            foreach (var descriptor in descriptorsToRemove)
            {
                services.Remove(descriptor);
            }

            services.AddSingleton<IEventBus>(EventBus);

            // Replace the Aspire-registered NpgsqlDataSource with one that has SSL disabled
            var npgsqlDescriptors = services
                .Where(d => d.ServiceType == typeof(NpgsqlDataSource))
                .ToList();
            foreach (var descriptor in npgsqlDescriptors)
            {
                services.Remove(descriptor);
            }

            services.AddSingleton(NpgsqlDataSource.Create(GetConnectionStringWithSslDisabled()));
        });
        return base.CreateHost(builder);
    }

    public async Task SeedDatabaseAsync()
    {
        var connectionString = GetConnectionStringWithSslDisabled();

        // Wait for the Postgres container to be ready
        for (var i = 0; i < 30; i++)
        {
            try
            {
                await using var testConn = new NpgsqlConnection(connectionString);
                await testConn.OpenAsync();
                break;
            }
            catch
            {
                await Task.Delay(TimeSpan.FromSeconds(1));
            }
        }

        await using var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync();

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            CREATE SCHEMA IF NOT EXISTS ordering;

            CREATE TABLE IF NOT EXISTS ordering.buyers (
                "Id" integer PRIMARY KEY,
                "IdentityGuid" varchar(200) NOT NULL,
                "Name" text
            );

            CREATE TABLE IF NOT EXISTS ordering.orders (
                "Id" integer PRIMARY KEY,
                "OrderStatus" varchar(30) NOT NULL DEFAULT '',
                "Description" text,
                "BuyerId" integer REFERENCES ordering.buyers("Id"),
                "OrderDate" timestamptz NOT NULL,
                "PaymentMethodId" integer,
                "Address_Street" text,
                "Address_City" text,
                "Address_State" text,
                "Address_Country" text,
                "Address_ZipCode" text,
                "Notes" varchar(500)
            );
            """;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task InsertOrderAsync(int orderId, string status, int buyerId, string buyerIdentityGuid, string buyerName)
    {
        await using var conn = new NpgsqlConnection(GetConnectionStringWithSslDisabled());
        await conn.OpenAsync();

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            INSERT INTO ordering.buyers ("Id", "IdentityGuid", "Name")
            VALUES (@BuyerId, @BuyerGuid, @BuyerName)
            ON CONFLICT ("Id") DO NOTHING;

            INSERT INTO ordering.orders ("Id", "OrderStatus", "BuyerId", "OrderDate")
            VALUES (@OrderId, @Status, @BuyerId, @OrderDate);
            """;
        cmd.Parameters.AddWithValue("BuyerId", buyerId);
        cmd.Parameters.AddWithValue("BuyerGuid", buyerIdentityGuid);
        cmd.Parameters.AddWithValue("BuyerName", buyerName);
        cmd.Parameters.AddWithValue("OrderId", orderId);
        cmd.Parameters.AddWithValue("Status", status);
        cmd.Parameters.AddWithValue("OrderDate", DateTime.UtcNow);
        await cmd.ExecuteNonQueryAsync();
    }

    public new async Task DisposeAsync()
    {
        await base.DisposeAsync();
        await _app.StopAsync();
        if (_app is IAsyncDisposable asyncDisposable)
        {
            await asyncDisposable.DisposeAsync().ConfigureAwait(false);
        }
        else
        {
            _app.Dispose();
        }
    }

    public async ValueTask InitializeAsync()
    {
        await _app.StartAsync();
        _postgresConnectionString = await Postgres.Resource.GetConnectionStringAsync();
        await SeedDatabaseAsync();
    }
}

public sealed class CapturingEventBus : IEventBus
{
    private readonly ConcurrentBag<IntegrationEvent> _publishedEvents = [];

    public IReadOnlyCollection<IntegrationEvent> PublishedEvents => _publishedEvents.ToArray();

    public Task PublishAsync(IntegrationEvent @event)
    {
        _publishedEvents.Add(@event);
        return Task.CompletedTask;
    }
}
