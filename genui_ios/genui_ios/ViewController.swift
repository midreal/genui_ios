import UIKit

/// Main demo list showing all available A2UI framework demonstrations.
class ViewController: UITableViewController {

    private let demos: [(title: String, subtitle: String, vcType: UIViewController.Type)] = [
        ("Gallery Examples", "a2ui_demo JSON 示例渲染", GalleryExamplesDemoVC.self),
        ("复合组件 & 容器组件 Demo", "Molecules & Organisms 展示", MoleculesAndOrganismsDemoVC.self),
        ("A2UI Writing Demo", "Watch AI write UI step by step", A2UIWritingDemoVC.self),
        ("v0.8 vs v0.9 speedCompare", "Speedcompare with wait time", V08V09CompareDemoVC.self),
        ("Component Gallery", "All 18 components with JSON viewer", ComponentGalleryVC.self),
        ("JSON Playground", "Input JSON and render live", JSONPlaygroundVC.self),
        ("Chat Demo", "AI chat with mock backend", ChatDemoVC.self),
        ("Streaming", "MockTransport simulated streaming", StreamingDemoVC.self),
        ("Interactive", "Full interaction loop with events", InteractiveDemoVC.self),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "A2UI iOS Demos"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        demos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let demo = demos[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = demo.title
        content.secondaryText = demo.subtitle
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let demo = demos[indexPath.row]
        let vc = demo.vcType.init()
        vc.title = demo.title
        navigationController?.pushViewController(vc, animated: true)
    }
}
