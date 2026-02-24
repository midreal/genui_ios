import UIKit

/// Main demo list showing all available A2UI framework demonstrations.
class ViewController: UITableViewController {

    private let demos: [(title: String, subtitle: String, vcType: UIViewController.Type)] = [
        ("Static Render", "SurfaceView recursive rendering", StaticRenderDemoVC.self),
        ("Data Binding", "Two-way DataModel ↔ UI binding", DataBindingDemoVC.self),
        ("JSON Parsing", "A2UI JSON → Engine → Render pipeline", JSONParsingDemoVC.self),
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
