import UIKit

/// Main demo list showing all available A2UI framework demonstrations.
class ViewController: UITableViewController {

    private let demos: [(title: String, subtitle: String, vcType: UIViewController.Type)] = [
        ("Component Gallery", "All 18 components with JSON viewer", ComponentGalleryVC.self),
        ("JSON Playground", "Input JSON and render live", JSONPlaygroundVC.self),
        ("Chat Demo", "AI chat with mock backend", ChatDemoVC.self),
        ("Static Render", "SurfaceView recursive rendering", StaticRenderDemoVC.self),
        ("Data Binding", "Two-way DataModel ↔ UI binding", DataBindingDemoVC.self),
        ("JSON Parsing", "A2UI JSON → Engine → Render pipeline", JSONParsingDemoVC.self),
        ("Streaming", "MockTransport simulated streaming", StreamingDemoVC.self),
        ("Interactive", "Full interaction loop with events", InteractiveDemoVC.self),
        ("v0.8 Compatibility", "Protocol v0.8 compatibility test suite", V08CompatibilityTestVC.self),
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
