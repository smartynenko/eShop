# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

eShop is a .NET reference application ("AdventureWorks") implementing an e-commerce platform using microservices orchestrated with .NET Aspire. It targets .NET 10 and uses PostgreSQL, Redis, RabbitMQ, and Duende IdentityServer.

## Build & run

```bash
# Build
dotnet build eShop.slnx           # full solution
dotnet build eShop.Web.slnf       # web-only (what CI builds)

# Run (requires Docker for containers)
dotnet run --project src/eShop.AppHost/eShop.AppHost.csproj
# Aspire dashboard URL appears in console output after startup
```

## Tests

```bash
dotnet test                        # all tests
dotnet test --project tests/Basket.UnitTests/Basket.UnitTests.csproj
dotnet test --filter "BasketServiceTests.GetBasketReturnsEmptyForNoUser"
```

Test projects: `Basket.UnitTests`, `Ordering.UnitTests`, `ClientApp.UnitTests` (no Docker needed); `Catalog.FunctionalTests`, `Ordering.FunctionalTests` (Docker required — Aspire spins up PostgreSQL containers).

Framework: MSTest with Microsoft.Testing.Platform. Mocking: NSubstitute. Functional tests use `WebApplicationFactory` + Aspire hosting.

## Architecture

### Aspire orchestration (`src/eShop.AppHost/Program.cs`)
The AppHost is the single entry point that wires every service together — it declares infrastructure resources (postgres, redis, rabbitMQ) and projects, threading connection strings through `WithReference`. Never hard-code connection strings in services; they are injected by the AppHost.

### Service defaults (`src/eShop.ServiceDefaults/`)
Every service calls `builder.AddServiceDefaults()`, which adds:
- OpenTelemetry (traces, metrics, logs via OTLP)
- Health check endpoints (`/health`, `/alive`)
- Service discovery + standard Polly resilience for all `HttpClient`s

### Authentication (`eShop.ServiceDefaults/AuthenticationExtensions.cs`)
JWT bearer auth is added only if an `"Identity"` section exists in config. Tokens flow between services via `HttpClientAuthorizationDelegatingHandler`. Identity is issued by the `Identity.API` Duende IdentityServer project.

### Event bus (`src/EventBus/`, `src/EventBusRabbitMQ/`)
Async inter-service messaging uses a thin in-repo abstraction over RabbitMQ:
- Publish: `IEventBus.PublishAsync(IntegrationEvent)`
- Subscribe: `.AddRabbitMqEventBus("eventbus").AddSubscription<TEvent, THandler>()`
- Handlers are registered as keyed transient services by event type
- Services that write to a DB also use `IntegrationEventLogEF` for reliable outbox-style publishing

### API patterns
All HTTP APIs use **minimal APIs** with `Asp.Versioning` (v8.1.0):
```csharp
var api = app.NewVersionedApi("Catalog").MapGroup("api/catalog")
    .HasApiVersion(1, 0).HasApiVersion(2, 0);
```
`Ordering.API` additionally uses **MediatR** (v13) for commands/queries, with pipeline behaviors for logging, FluentValidation, and transactions. Services are injected into endpoints via `[AsParameters]` structs (e.g., `OrderServices`).

`Basket.API` exposes a **gRPC** service (proto in `src/ClientApp/Services/Basket/Protos/`) backed by Redis.

### Database
- PostgreSQL via `Aspire.Npgsql.EntityFrameworkCore.PostgreSQL` (`AddNpgsqlDbContext<TContext>("dbname")`)
- Migrations + seeding run automatically at startup via `AddMigration<TContext, TSeed>()`
- Complex read queries use Dapper alongside EF Core (e.g., `IOrderQueries` in Ordering)
- `Catalog.API` enables pgvector for AI embedding-based semantic search

### AI / semantic search
Optional: set `useOpenAI = true` in `eShop.AppHost/Program.cs` and add connection strings for Azure OpenAI, or use Ollama via `CommunityToolkit.Aspire.Hosting.Ollama`.

## Code style

Enforced via `.editorconfig`:
- 4-space indentation for C#, 2-space for XML/props
- `var` everywhere (implicit typing preferred)
- No `this.` qualification
- Expression-bodied members for properties/accessors but **not** for methods
- Open braces on new line (Allman style)
- Sort `using` with System directives first
- PascalCase for `const` fields
