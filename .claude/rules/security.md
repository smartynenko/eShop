## No hardcoded connection strings

Aspire injects all connection strings via `WithReference` in `eShop.AppHost/Program.cs`.
Services consume them through `builder.AddNpgsqlDbContext`, `builder.AddRedisClient`, etc.
Never embed connection strings, passwords, or host addresses in service code or config files.

## No PII in logs

Never log customer names, email addresses, physical addresses, or card details.
When logging commands or events that contain PII, log only identifiers (order ID, request ID).

Follow the pattern in `OrdersApi.CreateOrderAsync`: mask the card number before passing it
to the command, and log only the command name and correlation ID — not the request body:

```csharp
// Good — masks CC, logs only IDs
var maskedCCNumber = request.CardNumber
    .Substring(request.CardNumber.Length - 4)
    .PadLeft(request.CardNumber.Length, 'X');
services.Logger.LogInformation(
    "Sending command: {CommandName} - {IdProperty}: {CommandId}",
    request.GetGenericTypeName(), nameof(request.UserId), request.UserId);

// Bad — leaks full card number and address into logs
services.Logger.LogInformation("Creating order: {@Request}", request);
```

When using `{@Object}` structured logging (Serilog destructuring), verify the object
contains no PII fields before logging it.

## All API endpoints require authentication

Apply `.RequireAuthorization()` to API route groups, as done in `Ordering.API/Program.cs`
and `Webhooks.API/Program.cs`. The only exceptions are:

- `/health` and `/alive` (mapped by `MapDefaultEndpoints()` in ServiceDefaults)
- The Identity.API itself (it issues tokens)

If adding a new service with HTTP endpoints, call `builder.AddDefaultAuthentication()`
and apply `.RequireAuthorization()` to the API group.

## No raw SQL without parameterization

Use EF Core LINQ queries (as in `OrderQueries`) or Dapper with parameterized queries.
When raw SQL is unavoidable (as in `GracePeriodManagerService`), always use parameters:

```csharp
// Good — parameterized
command.CommandText = "SELECT \"Id\" FROM ordering.orders WHERE \"OrderStatus\" = @Status";
command.Parameters.AddWithValue("Status", "Submitted");

// Bad — string interpolation in SQL
command.CommandText = $"SELECT \"Id\" FROM ordering.orders WHERE \"OrderStatus\" = '{status}'";
```

Never use string concatenation or interpolation to build SQL. This applies to EF Core's
`FromSqlRaw` and `ExecuteSqlRaw` as well — use `FromSqlInterpolated` or pass parameters.

## Never expose internal service URLs to external clients

Internal service names (e.g., `http://catalog-api`, `http://ordering-api`) are resolved
via Aspire service discovery and must never appear in API responses, error messages,
or client-facing configuration.

The `webapp` BFF is the only external entry point. Backend services communicate
internally through service discovery and the RabbitMQ event bus. If an API response
needs to reference another resource, use relative paths or public gateway URLs.
