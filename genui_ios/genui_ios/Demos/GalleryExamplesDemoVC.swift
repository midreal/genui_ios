import UIKit
import A2UI

/// 一屏展示所有 gallery 示例，每个示例直接渲染在列表中。
class GalleryExamplesDemoVC: UIViewController {

    private var controller: SurfaceController!

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.backgroundColor = .systemGroupedBackground
        return sv
    }()

    private lazy var stackView: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 20
        s.alignment = .fill
        return s
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Gallery Examples"

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        loadAndRenderAll()
    }

    private func loadAndRenderAll() {
        let urls = loadExampleURLs()
        guard !urls.isEmpty else {
            let label = UILabel()
            label.text = "未找到 JSON 示例文件"
            label.textColor = .secondaryLabel
            stackView.addArrangedSubview(label)
            return
        }

        let examples = urls
            .map { ($0, $0.deletingPathExtension().lastPathComponent) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }

        for (url, name) in examples {
            let displayName = formatDisplayName(name)

            guard let data = try? Data(contentsOf: url),
                  let parsed = try? JSONSerialization.jsonObject(with: data, options: []) else {
                stackView.addArrangedSubview(makeErrorCard(title: displayName, error: "JSON 解析失败"))
                continue
            }

            let jsonArray: [JsonMap]
            if let arr = parsed as? [JsonMap] { jsonArray = arr }
            else if let single = parsed as? JsonMap { jsonArray = [single] }
            else {
                stackView.addArrangedSubview(makeErrorCard(title: displayName, error: "无效 JSON"))
                continue
            }

            var messages: [A2UIMessage] = []
            var parseError: String?
            for (i, obj) in jsonArray.enumerated() {
                do {
                    messages.append(try A2UIMessage.fromJSON(obj))
                } catch {
                    parseError = "消息[\(i)]: \(error.localizedDescription)"
                    break
                }
            }
            if let err = parseError {
                stackView.addArrangedSubview(makeErrorCard(title: displayName, error: err))
                continue
            }

            for msg in messages { controller.handleMessage(msg) }

            guard let surfaceId = messages.first?.surfaceId else {
                stackView.addArrangedSubview(makeErrorCard(title: displayName, error: "无 surfaceId"))
                continue
            }

            stackView.addArrangedSubview(makeCard(title: displayName, surfaceId: surfaceId))
        }
    }

    // MARK: - File Discovery

    private func loadExampleURLs() -> [URL] {
        for subdir in ["GalleryExamples", "Resources/GalleryExamples"] {
            if let list = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: subdir), !list.isEmpty {
                return list
            }
        }
        if let allJson = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            let gallery = allJson.filter { url in
                let name = url.lastPathComponent
                return name.contains("_examples") || ["bio_profile", "email_viewer", "coffee_bean_picker", "subscription_picker"].contains(where: { name.hasPrefix($0) })
            }
            if !gallery.isEmpty { return gallery }
        }
        if let resourceURL = Bundle.main.resourceURL {
            for rel in ["GalleryExamples", "Resources/GalleryExamples"] {
                let dir = resourceURL.appendingPathComponent(rel, isDirectory: true)
                if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    let json = contents.filter { $0.pathExtension == "json" }
                    if !json.isEmpty { return json }
                }
            }
        }
        let thisFile = URL(fileURLWithPath: #filePath)
        var dir = thisFile
        for _ in 0..<5 { dir = dir.deletingLastPathComponent() }
        let examplesDir = dir.appendingPathComponent("a2ui_demo/resources/gallery/examples", isDirectory: true)
        if let urls = jsonFilesIn(examplesDir) { return urls }
        let hardcoded = URL(fileURLWithPath: "/Users/wldxw/macaron/a2ui_demo/resources/gallery/examples")
        if let urls = jsonFilesIn(hardcoded) { return urls }
        return []
    }

    private func jsonFilesIn(_ dir: URL) -> [URL]? {
        guard FileManager.default.fileExists(atPath: dir.path),
              let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return nil }
        let json = contents.filter { $0.pathExtension == "json" }
        return json.isEmpty ? nil : json
    }

    private func formatDisplayName(_ name: String) -> String {
        name.replacingOccurrences(of: "_examples", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    // MARK: - Card UI

    private func makeCard(title: String, surfaceId: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.clipsToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label

        let ctx = controller.contextFor(surfaceId: surfaceId)
        let surfaceView = SurfaceView(surfaceContext: ctx)

        let vStack = UIStackView(arrangedSubviews: [titleLabel, surfaceView])
        vStack.axis = .vertical
        vStack.spacing = 8
        vStack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        vStack.isLayoutMarginsRelativeArrangement = true

        card.addSubview(vStack)
        vStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func makeErrorCard(title: String, error: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.clipsToBounds = true

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 4
        vStack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        vStack.isLayoutMarginsRelativeArrangement = true
        card.addSubview(vStack)
        vStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        vStack.addArrangedSubview(titleLabel)

        let errorLabel = UILabel()
        errorLabel.text = error
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        vStack.addArrangedSubview(errorLabel)

        return card
    }
}
