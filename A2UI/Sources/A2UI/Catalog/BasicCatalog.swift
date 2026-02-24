import Foundation

/// Factory that assembles the built-in A2UI component catalog.
///
/// The basic catalog contains all 18 standard A2UI components, matching
/// the Flutter genui `BasicCatalogItems`.
public enum BasicCatalog {

    /// Creates the default catalog with all built-in components and functions.
    public static func create(catalogId: String = basicCatalogId) -> Catalog {
        Catalog(
            items: allItems(),
            functions: BuiltInFunctions.all(),
            catalogId: catalogId
        )
    }

    /// Returns all built-in catalog items.
    public static func allItems() -> [CatalogItem] {
        [
            // Core display
            TextComponent.register(),
            ButtonComponent.register(),
            // Layout
            ColumnComponent.register(),
            RowComponent.register(),
            CardComponent.register(),
            DividerComponent.register(),
            IconComponent.register(),
            // Data-bound inputs
            TextFieldComponent.register(),
            CheckBoxComponent.register(),
            SliderComponent.register(),
            ChoicePickerComponent.register(),
            DateTimeInputComponent.register(),
            // Advanced
            ListComponent.register(),
            TabsComponent.register(),
            ModalComponent.register(),
            ImageComponent.register(),
            AudioPlayerComponent.register(),
            VideoComponent.register(),
        ]
    }
}
