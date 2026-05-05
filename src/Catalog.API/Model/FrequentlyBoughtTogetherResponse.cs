namespace eShop.Catalog.API.Model;

public record FrequentlyBoughtTogetherResponse(int ProductId, IEnumerable<CatalogItem> Items);
