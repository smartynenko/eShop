using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Ordering.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddNotesToOrders : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Adding a nullable column with no default value is a metadata-only
            // operation in PostgreSQL — it does NOT rewrite the table and acquires
            // only a brief ACCESS EXCLUSIVE lock on the catalog entry (microseconds).
            // Existing rows read NULL for Notes until explicitly updated.
            migrationBuilder.AddColumn<string>(
                name: "Notes",
                schema: "ordering",
                table: "orders",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Notes",
                schema: "ordering",
                table: "orders");
        }
    }
}
