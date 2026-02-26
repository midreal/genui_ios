import UIKit
import Combine

/// Displays an image from a URL with variant-based sizing.
///
/// Parameters:
/// - `url`: The image URL (literal or data binding).
/// - `fit`: Content mode — "cover", "contain", "fill" (default "cover").
/// - `variant`: Size/style hint — "icon", "avatar", "smallFeature", "mediumFeature", "largeFeature", "header".
enum ImageComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Image") { context in
            let wrapper = BindableView()
            let imageView = UIImageView()
            imageView.contentMode = parseContentMode(context.data["fit"] as? String)
            imageView.clipsToBounds = true
            imageView.backgroundColor = .tertiarySystemFill
            imageView.layer.cornerRadius = 8
            imageView.translatesAutoresizingMaskIntoConstraints = false

            let variant = context.data["variant"] as? String
            let size = sizeForVariant(variant)

            if variant == "avatar" {
                imageView.layer.cornerRadius = size / 2
            }

            if variant == "header" {
                wrapper.embed(imageView)
            } else {
                wrapper.addSubview(imageView)
                NSLayoutConstraint.activate([
                    imageView.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    imageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                    imageView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: size),
                    imageView.heightAnchor.constraint(equalToConstant: size)
                ])
            }

            if let explicitWidth = context.data["width"] as? CGFloat {
                let c = imageView.widthAnchor.constraint(equalToConstant: explicitWidth)
                c.priority = .required
                c.isActive = true
            }
            if let explicitHeight = context.data["height"] as? CGFloat {
                let c = imageView.heightAnchor.constraint(equalToConstant: explicitHeight)
                c.priority = .required
                c.isActive = true
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

    private static func sizeForVariant(_ variant: String?) -> CGFloat {
        switch variant {
        case "icon", "avatar": return 32
        case "smallFeature": return 50
        case "mediumFeature": return 150
        case "largeFeature": return 400
        default: return 150
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
                UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve) {
                    imageView.image = image
                }
            }
        }.resume()
    }
}
