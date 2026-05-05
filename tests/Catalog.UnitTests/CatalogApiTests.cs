using System.Diagnostics.CodeAnalysis;
using eShop.Catalog.API;
using eShop.Catalog.API.Infrastructure;
using eShop.Catalog.API.IntegrationEvents;
using eShop.Catalog.API.Model;
using eShop.Catalog.API.Services;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace eShop.Catalog.UnitTests;

[TestClass]
public class CatalogApiTests
{
    private static TestCatalogContext CreateDbContext(string dbName)
    {
        var options = new DbContextOptionsBuilder<CatalogContext>()
            .UseInMemoryDatabase(dbName)
            .Options;

        var configuration = new ConfigurationBuilder().Build();
        return new TestCatalogContext(options, configuration);
    }

    private static CatalogServices CreateServices(CatalogContext context)
    {
        var catalogAI = Substitute.For<ICatalogAI>();
        var options = Options.Create(new CatalogOptions());
        var logger = NullLogger<CatalogServices>.Instance;
        var eventService = Substitute.For<ICatalogIntegrationEventService>();
        return new CatalogServices(context, catalogAI, options, logger, eventService);
    }

    [TestMethod]
    public async Task GetFrequentlyBoughtTogether_returns_bad_request_for_invalid_id()
    {
        using var context = CreateDbContext(nameof(GetFrequentlyBoughtTogether_returns_bad_request_for_invalid_id));
        var services = CreateServices(context);

        var result = await CatalogApi.GetFrequentlyBoughtTogether(services, id: 0, maxItems: 5);

        Assert.IsInstanceOfType<BadRequest<ProblemDetails>>(result.Result);
    }

    [TestMethod]
    public async Task GetFrequentlyBoughtTogether_returns_bad_request_for_invalid_maxItems()
    {
        using var context = CreateDbContext(nameof(GetFrequentlyBoughtTogether_returns_bad_request_for_invalid_maxItems));
        var services = CreateServices(context);

        var result = await CatalogApi.GetFrequentlyBoughtTogether(services, id: 1, maxItems: 0);

        Assert.IsInstanceOfType<BadRequest<ProblemDetails>>(result.Result);
    }

    [TestMethod]
    public async Task GetFrequentlyBoughtTogether_returns_bad_request_for_maxItems_over_20()
    {
        using var context = CreateDbContext(nameof(GetFrequentlyBoughtTogether_returns_bad_request_for_maxItems_over_20));
        var services = CreateServices(context);

        var result = await CatalogApi.GetFrequentlyBoughtTogether(services, id: 1, maxItems: 21);

        Assert.IsInstanceOfType<BadRequest<ProblemDetails>>(result.Result);
    }

    [TestMethod]
    public async Task GetFrequentlyBoughtTogether_returns_not_found_for_nonexistent_product()
    {
        using var context = CreateDbContext(nameof(GetFrequentlyBoughtTogether_returns_not_found_for_nonexistent_product));
        var services = CreateServices(context);

        var result = await CatalogApi.GetFrequentlyBoughtTogether(services, id: 999, maxItems: 5);

        Assert.IsInstanceOfType<NotFound>(result.Result);
    }

    [TestMethod]
    public async Task GetFrequentlyBoughtTogether_returns_empty_when_no_associations()
    {
        using var context = CreateDbContext(nameof(GetFrequentlyBoughtTogether_returns_empty_when_no_associations));
        context.CatalogItems.Add(new CatalogItem("Test Item") { Id = 1, CatalogBrandId = 1, CatalogTypeId = 1 });
        await context.SaveChangesAsync();

        var services = CreateServices(context);

        var result = await CatalogApi.GetFrequentlyBoughtTogether(services, id: 1, maxItems: 5);

        var okResult = (Ok<FrequentlyBoughtTogetherResponse>)result.Result;
        Assert.AreEqual(1, okResult.Value!.ProductId);
        Assert.IsFalse(okResult.Value.Items.Any());
    }

    [TestMethod]
    public async Task GetFrequentlyBoughtTogether_returns_items_ordered_by_order_count()
    {
        using var context = CreateDbContext(nameof(GetFrequentlyBoughtTogether_returns_items_ordered_by_order_count));

        context.CatalogItems.AddRange(
            new CatalogItem("Product A") { Id = 1, CatalogBrandId = 1, CatalogTypeId = 1 },
            new CatalogItem("Product B") { Id = 2, CatalogBrandId = 1, CatalogTypeId = 1 },
            new CatalogItem("Product C") { Id = 3, CatalogBrandId = 1, CatalogTypeId = 1 }
        );
        context.CatalogItemAssociations.AddRange(
            new CatalogItemAssociation { CatalogItemId = 1, RelatedCatalogItemId = 2, OrderCount = 5, LastUpdated = DateTime.UtcNow },
            new CatalogItemAssociation { CatalogItemId = 1, RelatedCatalogItemId = 3, OrderCount = 10, LastUpdated = DateTime.UtcNow }
        );
        await context.SaveChangesAsync();

        var services = CreateServices(context);

        var result = await CatalogApi.GetFrequentlyBoughtTogether(services, id: 1, maxItems: 5);

        var okResult = (Ok<FrequentlyBoughtTogetherResponse>)result.Result;
        var items = okResult.Value!.Items.ToList();
        Assert.AreEqual(2, items.Count);
        Assert.AreEqual(3, items[0].Id);
        Assert.AreEqual(2, items[1].Id);
    }

    [TestMethod]
    public async Task GetFrequentlyBoughtTogether_respects_maxItems_cap()
    {
        using var context = CreateDbContext(nameof(GetFrequentlyBoughtTogether_respects_maxItems_cap));

        context.CatalogItems.Add(new CatalogItem("Product A") { Id = 1, CatalogBrandId = 1, CatalogTypeId = 1 });
        for (var i = 2; i <= 10; i++)
        {
            context.CatalogItems.Add(new CatalogItem($"Product {i}") { Id = i, CatalogBrandId = 1, CatalogTypeId = 1 });
            context.CatalogItemAssociations.Add(new CatalogItemAssociation
            {
                CatalogItemId = 1,
                RelatedCatalogItemId = i,
                OrderCount = 100 - i,
                LastUpdated = DateTime.UtcNow
            });
        }
        await context.SaveChangesAsync();

        var services = CreateServices(context);

        var result = await CatalogApi.GetFrequentlyBoughtTogether(services, id: 1, maxItems: 3);

        var okResult = (Ok<FrequentlyBoughtTogetherResponse>)result.Result;
        var items = okResult.Value!.Items.ToList();
        Assert.AreEqual(3, items.Count);
    }
}
