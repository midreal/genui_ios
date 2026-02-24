# Integration Guide

Step-by-step guide for integrating A2UI into your iOS app.

## 1. Installation

### CocoaPods

Add to your `Podfile`:

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks! :linkage => :static
  pod 'A2UI', :git => 'https://github.com/tangfuhao/genui_ios.git'
end
```

Then run:

```bash
pod install
```

> **Note**: Use `:linkage => :static` to avoid Xcode sandbox issues with dynamic framework embedding.

## 2. Basic Usage — Render from JSON

The simplest integration: receive A2UI JSON from your backend and render it.

```swift
import A2UI

class MyViewController: UIViewController {

    private var controller: SurfaceController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Create the engine
        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        // 2. Process A2UI messages from your backend
        let json: JsonMap = ... // your JSON from the server
        if let message = try? A2UIMessage.fromJSON(json) {
            controller.handleMessage(message)
        }

        // 3. Create and embed the surface view
        let surfaceView = SurfaceView(
            surfaceContext: controller.contextFor(surfaceId: "your-surface-id")
        )
        view.addSubview(surfaceView)
        // ... add Auto Layout constraints
    }
}
```

## 3. Full Integration with Transport

For real-time streaming from your AI backend, implement `A2UITransport` and use `Conversation`:

```swift
import A2UI
import Combine

class ChatViewController: UIViewController {

    private var conversation: Conversation!
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Create your transport (implements A2UITransport)
        let transport = MyBackendTransport(endpoint: "wss://api.example.com/chat")

        // 2. Create the conversation facade
        let catalog = BasicCatalog.create()
        let controller = SurfaceController(catalogs: [catalog])
        conversation = Conversation(controller: controller, transport: transport)

        // 3. Listen for surface events
        conversation.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .surfaceAdded(let sid, _):
                    self?.showSurface(surfaceId: sid)
                case .surfaceRemoved(let sid):
                    self?.removeSurface(surfaceId: sid)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func showSurface(surfaceId: String) {
        let surfaceView = SurfaceView(
            surfaceContext: conversation.controller.contextFor(surfaceId: surfaceId)
        )
        // Add to your view hierarchy
    }

    deinit {
        conversation.dispose()
    }
}
```

## 4. Implementing A2UITransport

Create your own transport by conforming to `A2UITransport`:

```swift
import A2UI
import Combine

class MyBackendTransport: A2UITransport {

    private let messagesSubject = PassthroughSubject<A2UIMessage, Never>()
    private let textSubject = PassthroughSubject<String, Never>()

    var incomingMessages: AnyPublisher<A2UIMessage, Never> {
        messagesSubject.eraseToAnyPublisher()
    }

    var incomingText: AnyPublisher<String, Never> {
        textSubject.eraseToAnyPublisher()
    }

    func sendAction(_ event: UserActionEvent) async throws {
        // Send user event to your backend
        let jsonData = try JSONSerialization.data(withJSONObject: event.data)
        // ... POST to your API
    }

    func dispose() {
        messagesSubject.send(completion: .finished)
        textSubject.send(completion: .finished)
    }

    // Call this when your backend sends A2UI JSON
    func onReceiveJSON(_ json: JsonMap) {
        if let message = try? A2UIMessage.fromJSON(json) {
            messagesSubject.send(message)
        }
    }

    // For streaming text responses
    func onReceiveText(_ text: String) {
        textSubject.send(text)
    }
}
```

### Using the Stream Parser for SSE/Streaming

If your backend streams JSON embedded in text (e.g. Server-Sent Events), use `A2UITransportAdapter`:

```swift
let adapter = A2UITransportAdapter()

// Feed raw text chunks as they arrive
adapter.addChunk("Here is the weather: ```json\n{\"version\":\"v0.9\"...")
adapter.addChunk("...more data...")

// Subscribe to parsed messages
adapter.messages
    .sink { message in
        controller.handleMessage(message)
    }
    .store(in: &cancellables)
```

## 5. Custom Components

Extend the catalog with your own components:

```swift
let mapComponent = CatalogItem(name: "MapView") { context in
    let mapView = MKMapView()
    let lat = context.data["latitude"] as? Double ?? 0
    let lon = context.data["longitude"] as? Double ?? 0
    mapView.centerCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    return mapView
}

let catalog = BasicCatalog.create().copyWith(newItems: [mapComponent])
```

Now the AI can send `{ "component": "MapView", "latitude": 31.23, "longitude": 121.47 }`.

## 6. Handling User Events

Listen for events from A2UI components:

```swift
controller.onSubmit
    .receive(on: DispatchQueue.main)
    .sink { event in
        let data = event.data
        if let eventInfo = data["event"] as? JsonMap,
           let name = eventInfo["name"] as? String {
            switch name {
            case "submit_form":
                // Read data model values
                let model = controller.store.getDataModel(surfaceId: "my-surface")
                let name = model.getValue(path: DataPath("/name")) as? String
                // Process the form...
            default:
                break
            }
        }
    }
    .store(in: &cancellables)
```

## 7. Testing with MockTransport

Use `MockTransport` for development without a real backend:

```swift
let mock = MockTransport()
let controller = SurfaceController(catalogs: [BasicCatalog.create()])
let conversation = Conversation(controller: controller, transport: mock)

// Simulate AI sending messages with delays
mock.sendSequence([
    .createSurface(CreateSurfacePayload(surfaceId: "test", catalogId: basicCatalogId)),
    .updateComponents(UpdateComponentsPayload(surfaceId: "test", components: [
        Component(id: "root", type: "Text", properties: ["text": "Hello from Mock!"])
    ]))
], delay: 0.5)
```
