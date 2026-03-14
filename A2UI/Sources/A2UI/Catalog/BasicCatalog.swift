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
            LabelComponent.register(),
            ButtonComponent.register(),
            // Layout
            ColumnComponent.register(),
            RowComponent.register(),
            CardComponent.register(),
            DividerComponent.register(),
            IconComponent.register(),
            BottomBarComponent.register(),
            // Data-bound inputs
            TextFieldComponent.register(),
            CheckBoxComponent.register(),
            SliderComponent.register(),
            ChoicePickerComponent.register(),
            DateTimeInputComponent.register(),
            // Selection components
            SelectionListComponent.register(),
            SelectionGridComponent.register(),
            SelectionWrapComponent.register(),
            OrderedSelectionListComponent.register(),
            ActionSelectionListComponent.register(),
            DropdownSelectionComponent.register(),
            // Macaron display
            CircularProgressComponent.register(),
            LinearProgressComponent.register(),
            RatingComponent.register(),
            TagTextComponent.register(),
            FilterTagsComponent.register(),
            TickSliderComponent.register(),
            MapComponent.register(),
            MarkdownViewComponent.register(),
            OrderedDisplayListComponent.register(),
            // Macaron pickers
            RollPickerComponent.register(),
            RollPickerComponent.registerCard(),
            PasswordKeypadComponent.register(),
            // Logic
            BooleanAllOfComponent.register(),
            // Advanced
            ListComponent.register(),
            TabsComponent.register(),
            CarouselComponent.register(),
            ModalComponent.register(),
            FullScreenModalComponent.register(),
            ImageComponent.register(),
            PhotoInputComponent.register(),
        ]
    }
}
