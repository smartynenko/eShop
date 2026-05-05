using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace eShop.Catalog.API.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddCatalogItemAssociation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CatalogItemAssociation",
                columns: table => new
                {
                    CatalogItemId = table.Column<int>(type: "integer", nullable: false),
                    RelatedCatalogItemId = table.Column<int>(type: "integer", nullable: false),
                    OrderCount = table.Column<int>(type: "integer", nullable: false),
                    LastUpdated = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CatalogItemAssociation", x => new { x.CatalogItemId, x.RelatedCatalogItemId });
                    table.ForeignKey(
                        name: "FK_CatalogItemAssociation_Catalog_CatalogItemId",
                        column: x => x.CatalogItemId,
                        principalTable: "Catalog",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CatalogItemAssociation_Catalog_RelatedCatalogItemId",
                        column: x => x.RelatedCatalogItemId,
                        principalTable: "Catalog",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CatalogItemAssociation_CatalogItemId_OrderCount",
                table: "CatalogItemAssociation",
                columns: new[] { "CatalogItemId", "OrderCount" });

            migrationBuilder.CreateIndex(
                name: "IX_CatalogItemAssociation_RelatedCatalogItemId",
                table: "CatalogItemAssociation",
                column: "RelatedCatalogItemId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CatalogItemAssociation");
        }
    }
}
