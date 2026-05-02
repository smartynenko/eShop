## Test frameworks

Unit tests use **MSTest** (`MSTest.Sdk` project SDK) with `[TestClass]` and `[TestMethod]`.
Functional tests use **xUnit** (`xunit.v3.mtp-v2`) with `[Fact]` and `[Theory]`/`[InlineData]`,
hosted via the `Aspire.AppHost.Sdk` project SDK.

Do not mix frameworks within a single test project.

## Naming conventions

**Test projects:** `{ServiceName}.UnitTests` or `{ServiceName}.FunctionalTests`.

**Test classes:** `{SubjectUnderTest}Test` or `{SubjectUnderTest}Tests` — e.g.,
`OrderAggregateTest`, `BasketServiceTests`, `OrdersWebApiTest`.

**Test methods:** Use snake_case describing the scenario and expected outcome:
```csharp
Handle_return_false_if_order_is_not_persisted()
Cancel_order_with_requestId_success()
Create_buyer_item_fail()
```
For simpler cases, PascalCase describing the action is also accepted:
```csharp
GetBasketReturnsEmptyForNoUser()
GetCatalogItemsRespectsPageSize()
```

Pick one style per test class and stay consistent within it.

## Mocking with NSubstitute

Unit tests mock dependencies with **NSubstitute** (never Moq). Include
`NSubstitute.Analyzers.CSharp` as a dev-only analyzer to catch misuse at compile time.

Create mocks via `Substitute.For<T>()`, configure with `.Returns()`, and verify
with `.Received()` / `.DidNotReceive()`:
```csharp
var repo = Substitute.For<IOrderRepository>();
repo.GetAsync(Arg.Any<int>()).Returns(Task.FromResult(fakeOrder));
// ...
await repo.Received().GetAsync(Arg.Any<int>());
```

For loggers, use `NullLogger<T>.Instance` (not a mock) unless you need to verify
log calls.

## Test structure

Follow **Arrange / Act / Assert** in every test. Declare mock fields in the constructor
(for tests that share them) or inline in the method (for one-off tests).

Use builder/helper classes for complex domain objects — see `OrderBuilder` and
`AddressBuilder` in `Ordering.UnitTests/Builders.cs`. Place shared helpers in a
`Helpers/` folder within the test project.

Use `GlobalUsings.cs` to centralize common using directives and NSubstitute imports.
Enable parallel execution for unit tests:
```csharp
[assembly: Parallelize(Workers = 0, Scope = ExecutionScope.MethodLevel)]
```

## Assertions

Unit tests use MSTest's `Assert` class: `Assert.IsTrue`, `Assert.AreEqual`,
`Assert.IsInstanceOfType<T>`, `Assert.ThrowsExactly<T>`, `Assert.HasCount`,
`Assert.IsNotNull`, `Assert.IsEmpty`.

Functional tests use xUnit's `Assert` class: `Assert.Equal`, `Assert.NotNull`,
`Assert.All`, `Assert.Contains`.

## Functional tests with Aspire test hosting

Functional test projects use `Aspire.AppHost.Sdk` and spin up real infrastructure
(PostgreSQL containers) — they require Docker.

Each service gets a **fixture class** that extends `WebApplicationFactory<Program>`
and implements `IAsyncLifetime`:

1. In the constructor, create a `DistributedApplication` with `DisableDashboard = true`
   and add required infrastructure resources (Postgres, etc.).
2. In `InitializeAsync`, start the Aspire app and capture connection strings.
3. In `CreateHost`, inject connection strings via `AddInMemoryCollection` so the
   service under test connects to the test containers.
4. In `DisposeAsync`, stop and dispose both the `WebApplicationFactory` and the
   Aspire app.

```csharp
public sealed class CatalogApiFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly IHost _app;
    public IResourceBuilder<PostgresServerResource> Postgres { get; private set; }
    // ... see tests/Catalog.FunctionalTests/CatalogApiFixture.cs
}
```

Test classes consume fixtures via `IClassFixture<T>`:
```csharp
public sealed class CatalogApiTests : IClassFixture<CatalogApiFixture> { ... }
```

Reference the service-under-test project with `IsAspireProjectResource="false"` in
the csproj so it is not treated as an Aspire resource:
```xml
<ProjectReference Include="..\..\src\Catalog.API\Catalog.API.csproj"
                  IsAspireProjectResource="false" />
```

## Bypassing auth in functional tests

Services that require authentication use an `AutoAuthorizeMiddleware` injected via
`IStartupFilter` that stamps every request with a fake identity. See
`Ordering.FunctionalTests/AutoAuthorizeMiddleware.cs` for the pattern. Do not
disable authentication entirely — inject a middleware that sets known claims instead.

## API versioning in functional tests

Test all active API versions. Use `ApiVersionHandler` with `QueryStringApiVersionWriter`
to send version as a query parameter:
```csharp
[Theory]
[InlineData(1.0)]
[InlineData(2.0)]
public async Task GetCatalogItemsRespectsPageSize(double version)
{
    var client = CreateHttpClient(new ApiVersion(version));
    // ...
}
```

## What to unit test vs. functional test

**Unit test** (no Docker, no real DB, fast):
- Domain model invariants: aggregate creation, validation, domain events
  (e.g., `OrderAggregateTest`, `BuyerAggregateTest`)
- Command/query handlers: mock repositories and mediator, verify handler logic
  (e.g., `NewOrderRequestHandlerTest`, `IdentifiedCommandHandlerTest`)
- Minimal API endpoint logic: call the static API method directly with mocked
  services, assert on typed results like `Ok<T>`, `BadRequest`, `NotFound`
  (e.g., `OrdersWebApiTest`)
- gRPC service logic: use `TestServerCallContext` helper to simulate gRPC calls
  with mocked repositories (e.g., `BasketServiceTests`)
- Serialization round-trips for commands/DTOs

**Functional test** (Docker required, real DB, slower):
- Full HTTP request/response cycle through the real service pipeline
- Database seeding, migrations, and query correctness against real PostgreSQL
- API versioning behavior across v1 and v2 endpoints
- CRUD operations end-to-end: create, read, update, delete
- Integration with Aspire-managed infrastructure (connection strings, health checks)

Rule of thumb: if the test needs a real database or the full ASP.NET middleware
pipeline, it is a functional test. Everything else is a unit test.
