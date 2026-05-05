namespace eShop.Catalog.API.Infrastructure.EntityConfigurations;

class CatalogItemAssociationEntityTypeConfiguration : IEntityTypeConfiguration<CatalogItemAssociation>
{
    public void Configure(EntityTypeBuilder<CatalogItemAssociation> builder)
    {
        builder.ToTable("CatalogItemAssociation");

        builder.HasKey(a => new { a.CatalogItemId, a.RelatedCatalogItemId });

        builder.HasOne<CatalogItem>()
            .WithMany()
            .HasForeignKey(a => a.CatalogItemId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<CatalogItem>()
            .WithMany()
            .HasForeignKey(a => a.RelatedCatalogItemId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(a => new { a.CatalogItemId, a.OrderCount });
    }
}
