namespace eShop.Catalog.API.Model;

public class CatalogItemAssociation
{
    public int CatalogItemId { get; set; }
    public int RelatedCatalogItemId { get; set; }
    public int OrderCount { get; set; }
    public DateTime LastUpdated { get; set; }
}
