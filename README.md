# A2UI — iOS UIKit Implementation

A native iOS UIKit framework implementing the **A2UI (Agent-to-UI) Protocol v0.9**. Enables AI agents to dynamically generate, update, and interact with native iOS user interfaces through structured JSON messages.

## What is A2UI?

A2UI defines a protocol for AI systems to create rich, interactive UIs at runtime. Instead of hardcoding screens, the AI sends JSON messages that describe UI components, data bindings, and user interactions. This library renders those messages as native UIKit views.

```
┌─────────────┐    JSON Messages    ┌─────────────┐    UIKit Views    ┌─────────────┐
│  AI Backend  │ ──────────────────► │    A2UI      │ ────────────────► │   Screen    │
│  (any LLM)   │ ◄────────────────── │   Engine     │ ◄──────────────── │  (native)   │
└─────────────┘    User Events      └─────────────┘    Interactions    └─────────────┘
```

## Key Features

- **18 built-in components**: Text, Button, Column, Row, Card, TextField, Slider, CheckBox, Tabs, List, Image, and more
- **Reactive data binding**: Two-way binding powered by Combine, path-based data model
- **Streaming support**: Progressive UI rendering as JSON messages arrive
- **Transport-agnostic**: Pluggable transport layer — bring your own backend
- **12 client functions**: Validation (required, email, regex) and formatting (date, currency, number)
- **Zero AI dependency**: Pure UI framework; AI communication is abstracted behind `A2UITransport`

## Project Structure

```
genui_ios/
├── A2UI/                          # The library (CocoaPods)
│   ├── A2UI.podspec
│   └── Sources/A2UI/
│       ├── Model/                 # Protocol message types
│       ├── DataBinding/           # Reactive data model & context
│       ├── Engine/                # SurfaceController, Registry, Store
│       ├── Catalog/               # Component registry & 18 components
│       ├── Rendering/             # SurfaceView & SurfaceContext
│       ├── Transport/             # Transport protocol & MockTransport
│       ├── Functions/             # Built-in client functions
│       └── Facade/                # Conversation high-level API
├── genui_ios/                     # Example app
│   ├── Podfile
│   └── genui_ios/
│       ├── Demos/                 # 5 demo view controllers
│       └── MockData/              # Sample A2UI JSON files
└── docs/                          # Architecture documentation
```

## Quick Start

### Requirements

- iOS 15.0+
- Xcode 15+
- CocoaPods

### Run the Example App

```bash
cd genui_ios
pod install
open genui_ios.xcworkspace
```

Select the `genui_ios` scheme, choose a simulator, and run. The app contains 5 demos:

| Demo | What it shows |
|------|--------------|
| **Static Render** | Programmatic SurfaceDefinition → UIView tree |
| **Data Binding** | Two-way TextField/Slider/CheckBox ↔ DataModel |
| **JSON Parsing** | Raw JSON → A2UIMessage → Engine → Render |
| **Streaming** | MockTransport progressive UI delivery |
| **Interactive** | Full event loop: form → submit → validate → respond |

### Integrate into Your Project

Add to your `Podfile`:

```ruby
pod 'A2UI', :git => 'https://github.com/tangfuhao/genui_ios.git'
```

Then `pod install`. See [Integration Guide](docs/integration-guide.md) for details.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System layers, object ownership, data flow |
| [Protocol](docs/protocol.md) | A2UI message format specification |
| [Components](docs/components.md) | All 18 components with properties reference |
| [Data Binding](docs/data-binding.md) | Reactive data model, paths, contexts |
| [Integration Guide](docs/integration-guide.md) | Step-by-step guide for app developers |

## License

MIT
