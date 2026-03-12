import UIKit

/// A component that opens content in a full-screen modal route.
///
/// This component renders only `entryPointChild`. The `contentChild`
/// is used when `showFullModal` is dispatched with `modalId`.
///
/// Parameters:
/// - `entryPointChild`: The widget that opens the full-screen modal.
/// - `contentChild`: The widget to render inside the full-screen modal.
enum FullScreenModalComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "FullScreenModal") { context in
            let entryPointChildId = context.data["entryPointChild"] as? String
            guard let entryPointChildId = entryPointChildId else {
                return UIView()
            }
            return context.buildChild(entryPointChildId, nil)
        }
    }
}
