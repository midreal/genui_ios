import UIKit
import Combine

/// Displays an image from a URL.
///
/// Parameters:
/// - `url`: The image URL (literal or data binding).
/// - `width`: Optional fixed width.
/// - `height`: Optional fixed height.
/// - `fit`: Content mode — "cover", "contain", "fill" (default "cover").
enum ImageComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Image") { context in
            let wrapper = BindableView()
            let imageView = UIImageView()
            imageView.contentMode = parseContentMode(context.data["fit"] as? String)
            imageView.clipsToBounds = true
            imageView.backgroundColor = .tertiarySystemFill
            imageView.layer.cornerRadius = 8
            wrapper.embed(imageView)

            if let width = context.data["width"] as? CGFloat {
                imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
            }
            if let height = context.data["height"] as? CGFloat {
                imageView.heightAnchor.constraint(equalToConstant: height).isActive = true
            }

            let urlValue = context.data["url"]
            let cancellable = context.dataContext.resolve(urlValue)
                .receive(on: DispatchQueue.main)
                .sink { [weak imageView] value in
                    guard let imageView = imageView,
                          let urlStr = value as? String,
                          let url = URL(string: urlStr) else { return }
                    loadImage(url: url, into: imageView)
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }

    private static func parseContentMode(_ fit: String?) -> UIView.ContentMode {
        switch fit {
        case "contain": return .scaleAspectFit
        case "fill": return .scaleToFill
        default: return .scaleAspectFill
        }
    }

    private static func loadImage(url: URL, into imageView: UIImageView) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                imageView.image = image
            }
        }.resume()
    }
}
