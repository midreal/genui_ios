import UIKit

/// A collection of UI component types that the rendering engine can use
/// to construct a view hierarchy from A2UI messages.
///
/// Catalogs are composable: use `copyWith` to extend with custom components,
/// or `copyWithout` to remove components.
public final class Catalog {

    /// The registered component items.
    public let items: [CatalogItem]

    /// The registered client functions.
    public let functions: [ClientFunction]

    /// A unique identifier for this catalog (reverse-domain notation recommended).
    public let catalogId: String?

    private let itemsByName: [String: CatalogItem]

    public init(
        items: [CatalogItem],
        functions: [ClientFunction] = [],
        catalogId: String? = nil
    ) {
        self.items = items
        self.functions = functions
        self.catalogId = catalogId
        self.itemsByName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
    }

    /// Builds a UIView for the given component context.
    ///
    /// Looks up the `CatalogItem` by type name and invokes its builder.
    public func buildView(context: CatalogItemContext) -> UIView {
        guard let item = itemsByName[context.type] else {
            let label = UILabel()
            label.text = "Unknown: \(context.type)"
            label.textColor = .systemRed
            label.font = .systemFont(ofSize: 12)
            return label
        }
        return item.viewBuilder(context)
    }

    /// Returns a catalog item by type name.
    public func item(named name: String) -> CatalogItem? {
        itemsByName[name]
    }

    /// Returns a new catalog with additional or replaced items/functions.
    public func copyWith(
        newItems: [CatalogItem]? = nil,
        newFunctions: [ClientFunction]? = nil,
        catalogId: String? = nil
    ) -> Catalog {
        var merged = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
        if let additions = newItems {
            for item in additions { merged[item.name] = item }
        }

        var mergedFuncs = Dictionary(uniqueKeysWithValues: functions.map { ($0.name, $0) })
        if let additions = newFunctions {
            for f in additions { mergedFuncs[f.name] = f }
        }

        return Catalog(
            items: Array(merged.values),
            functions: Array(mergedFuncs.values),
            catalogId: catalogId ?? self.catalogId
        )
    }

    /// Returns a new catalog with specified items/functions removed.
    public func copyWithout(
        itemNames: Set<String>? = nil,
        functionNames: Set<String>? = nil,
        catalogId: String? = nil
    ) -> Catalog {
        let filteredItems = itemNames == nil
            ? items
            : items.filter { !itemNames!.contains($0.name) }
        let filteredFuncs = functionNames == nil
            ? functions
            : functions.filter { !functionNames!.contains($0.name) }
        return Catalog(
            items: filteredItems,
            functions: filteredFuncs,
            catalogId: catalogId ?? self.catalogId
        )
    }
}
