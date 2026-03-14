import UIKit
import A2UI

/// 列表展示 gallery 示例，点击进入详情页单独渲染（多 SurfaceView 同屏有布局竞态，单独展示稳定）。
class GalleryExamplesDemoVC: UIViewController {

    private var controller: SurfaceController!
    private var examples: [(displayName: String, surfaceId: String)] = []
    private var errorItems: [(displayName: String, error: String)] = []

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Gallery Examples"

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        loadExamples()
    }

    private func loadExamples() {
        let urls = loadExampleURLs()
        guard !urls.isEmpty else {
            errorItems.append(("未找到 JSON 示例文件", ""))
            tableView.reloadData()
            return
        }

        let sorted = urls
            .map { ($0, $0.deletingPathExtension().lastPathComponent) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }

        for (url, name) in sorted {
            let displayName = formatDisplayName(name)

            guard let data = try? Data(contentsOf: url),
                  let parsed = try? JSONSerialization.jsonObject(with: data, options: []) else {
                errorItems.append((displayName, "JSON 解析失败"))
                continue
            }

            let jsonArray: [JsonMap]
            if let arr = parsed as? [JsonMap] { jsonArray = arr }
            else if let single = parsed as? JsonMap { jsonArray = [single] }
            else {
                errorItems.append((displayName, "无效 JSON"))
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
                errorItems.append((displayName, err))
                continue
            }

            for msg in messages { controller.handleMessage(msg) }

            guard let surfaceId = messages.first?.surfaceId else {
                errorItems.append((displayName, "无 surfaceId"))
                continue
            }

            examples.append((displayName, surfaceId))
        }

        tableView.reloadData()
    }

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

    private func showDetail(surfaceId: String, title: String) {
        let vc = GalleryExampleDetailVC(controller: controller, surfaceId: surfaceId)
        vc.title = title
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension GalleryExamplesDemoVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        (examples.isEmpty ? 0 : 1) + (errorItems.isEmpty ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return examples.isEmpty ? errorItems.count : examples.count
        }
        return errorItems.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && !examples.isEmpty { return "示例" }
        if (!examples.isEmpty && section == 1) || (examples.isEmpty && section == 0) {
            return "错误"
        }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if !examples.isEmpty && indexPath.section == 0 {
            let item = examples[indexPath.row]
            cell.textLabel?.text = item.displayName
            cell.textLabel?.textColor = .label
            cell.accessoryType = .disclosureIndicator
        } else {
            let item = errorItems[indexPath.row]
            cell.textLabel?.text = item.error.isEmpty ? item.displayName : "\(item.displayName): \(item.error)"
            cell.textLabel?.textColor = item.error.isEmpty ? .label : .systemRed
            cell.accessoryType = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !examples.isEmpty, indexPath.section == 0 else { return }
        let item = examples[indexPath.row]
        showDetail(surfaceId: item.surfaceId, title: item.displayName)
    }
}

// MARK: - Detail VC (single SurfaceView)

private final class GalleryExampleDetailVC: UIViewController {

    private let controller: SurfaceController
    private let surfaceId: String

    init(controller: SurfaceController, surfaceId: String) {
        self.controller = controller
        self.surfaceId = surfaceId
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let ctx = controller.contextFor(surfaceId: surfaceId)
        let surfaceView = SurfaceView(surfaceContext: ctx)
        surfaceView.backgroundColor = .systemBackground

        // 用 ScrollView 包裹，打破 layoutSubviews 布局循环（filter_tags/slack_water 等会触发 50+ 次）
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(surfaceView)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            surfaceView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            surfaceView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            surfaceView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            surfaceView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            surfaceView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }
}
