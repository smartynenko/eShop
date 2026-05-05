using System.Diagnostics.CodeAnalysis;
using eShop.Catalog.API.Infrastructure;
using eShop.Catalog.API.Model;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace eShop.Catalog.UnitTests;

public class TestCatalogContext : CatalogContext
{
    [SetsRequiredMembers]
    public TestCatalogContext(DbContextOptions<CatalogContext> options, IConfiguration configuration)
        : base(options, configuration)
    {
    }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.Entity<CatalogItem>(b =>
        {
            b.Ignore(ci => ci.Embedding);
        });

        builder.Entity<CatalogItemAssociation>(b =>
        {
            b.HasKey(a => new { a.CatalogItemId, a.RelatedCatalogItemId });
            b.HasIndex(a => new { a.CatalogItemId, a.OrderCount });
        });
    }
}
