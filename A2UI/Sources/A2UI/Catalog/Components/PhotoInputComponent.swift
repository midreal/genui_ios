import UIKit
import Combine

/// A photo input component that displays a camera/gallery picker placeholder.
///
/// Parameters:
/// - `value`: Data-bound URL string for the uploaded photo.
/// - `hasValue`: Data-bound boolean, true after upload succeeds.
/// - `isUploading`: Data-bound boolean, true while uploading.
/// - `placeholder`: Placeholder text shown in empty state.
enum PhotoInputComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "PhotoInput") { context in
            let wrapper = BindableView()

            let container = UIView()
            container.backgroundColor = .tertiarySystemFill
            container.layer.cornerRadius = 12
            container.clipsToBounds = true
            container.translatesAutoresizingMaskIntoConstraints = false

            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.isHidden = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: container.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            let placeholderStack = UIStackView()
            placeholderStack.axis = .vertical
            placeholderStack.alignment = .center
            placeholderStack.spacing = 8
            placeholderStack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(placeholderStack)
            NSLayoutConstraint.activate([
                placeholderStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                placeholderStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])

            let cameraIcon = UIImageView(image: UIImage(systemName: "camera.fill"))
            cameraIcon.tintColor = .secondaryLabel
            cameraIcon.contentMode = .scaleAspectFit
            cameraIcon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cameraIcon.widthAnchor.constraint(equalToConstant: 32),
                cameraIcon.heightAnchor.constraint(equalToConstant: 32),
            ])
            placeholderStack.addArrangedSubview(cameraIcon)

            let placeholderLabel = UILabel()
            placeholderLabel.textColor = .secondaryLabel
            placeholderLabel.font = .systemFont(ofSize: 14)
            placeholderLabel.textAlignment = .center
            placeholderStack.addArrangedSubview(placeholderLabel)

            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.hidesWhenStopped = true
            spinner.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])

            wrapper.embed(container)
            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: 160),
            ])

            // Bind placeholder text
            let placeholderDef = context.data["placeholder"]
            let pCanc = BoundValueHelpers.resolveString(placeholderDef, context: context.dataContext)
                .receive(on: DispatchQueue.main)
                .sink { [weak placeholderLabel] value in
                    placeholderLabel?.text = value ?? "Tap to add photo"
                }
            wrapper.storeCancellable(pCanc)

            // Bind value (photo URL)
            let valueDef = context.data["value"]
            let vCanc = context.dataContext.resolve(valueDef)
                .receive(on: DispatchQueue.main)
                .sink { [weak imageView, weak placeholderStack] value in
                    if let urlStr = value as? String, !urlStr.isEmpty,
                       let url = URL(string: urlStr) {
                        placeholderStack?.isHidden = true
                        imageView?.isHidden = false
                        URLSession.shared.dataTask(with: url) { data, _, _ in
                            if let data = data, let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    imageView?.image = image
                                }
                            }
                        }.resume()
                    } else {
                        placeholderStack?.isHidden = false
                        imageView?.isHidden = true
                    }
                }
            wrapper.storeCancellable(vCanc)

            // Bind isUploading
            let uploadDef = context.data["isUploading"]
            let uCanc = context.dataContext.resolve(uploadDef)
                .receive(on: DispatchQueue.main)
                .sink { [weak spinner, weak placeholderStack] value in
                    if let uploading = value as? Bool, uploading {
                        spinner?.startAnimating()
                        placeholderStack?.isHidden = true
                    } else {
                        spinner?.stopAnimating()
                    }
                }
            wrapper.storeCancellable(uCanc)

            return wrapper
        }
    }
}
