import UIKit
import Combine

/// Displays an image from a URL with variant-based sizing.
///
/// Parameters:
/// - `url`: The image URL (literal or data binding).
/// - `fit`: Content mode — `"cover"`, `"contain"`, `"fill"`, `"fitWidth"`,
///   `"fitHeight"`, `"none"`, `"scaleDown"` (default `"cover"`).
/// - `variant`: Size/style hint — `"icon"`, `"avatar"`, `"smallFeature"`,
///   `"mediumFeature"`, `"largeFeature"`, `"header"`.
/// - `width` / `height`: Explicit size overrides.
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

            // Loading indicator
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.hidesWhenStopped = true
            imageView.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
            ])

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

            if let explicitWidth = (context.data["width"] as? NSNumber)?.doubleValue {
                let c = imageView.widthAnchor.constraint(equalToConstant: CGFloat(explicitWidth))
                c.priority = .required
                c.isActive = true
            }
            if let explicitHeight = (context.data["height"] as? NSNumber)?.doubleValue {
                let c = imageView.heightAnchor.constraint(equalToConstant: CGFloat(explicitHeight))
                c.priority = .required
                c.isActive = true
            }

            let urlValue = context.data["url"]
            let cancellable = context.dataContext.resolve(urlValue)
                .receive(on: DispatchQueue.main)
                .sink { [weak imageView, weak spinner] value in
                    guard let imageView = imageView else { return }
                    guard let urlStr = value as? String,
                          let url = URL(string: urlStr) else {
                        showErrorIcon(in: imageView)
                        return
                    }
                    spinner?.startAnimating()
                    loadImage(url: url, into: imageView) {
                        spinner?.stopAnimating()
                    }
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
        case "contain", "scaleDown": return .scaleAspectFit
        case "fill": return .scaleToFill
        case "fitWidth": return .scaleAspectFit
        case "fitHeight": return .scaleAspectFit
        case "none": return .center
        default: return .scaleAspectFill
        }
    }

    private static func showErrorIcon(in imageView: UIImageView) {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        imageView.image = UIImage(systemName: "photo.badge.exclamationmark", withConfiguration: config)
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .center
    }

    private static func loadImage(url: URL, into imageView: UIImageView, completion: @escaping () -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                completion()
                if let data = data, let image = UIImage(data: data) {
                    UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve) {
                        imageView.image = image
                    }
                } else {
                    showErrorIcon(in: imageView)
                }
            }
        }.resume()
    }
}
