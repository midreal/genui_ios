# Architecture

## Overview

A2UI iOS is a layered framework that transforms structured JSON messages into native UIKit views. The architecture separates concerns into 6 distinct layers, each with clear responsibilities and boundaries.

```
┌──────────────────────────────────────────────────────────┐
│                     App / Caller                         │
│  (ViewController, SwiftUI Host, etc.)                    │
├──────────────────────────────────────────────────────────┤
│                   Facade Layer                           │
│  Conversation                                            │
├──────────────────────────────────────────────────────────┤
│                  Transport Layer                         │
│  A2UITransport ← A2UIStreamParser ← MockTransport       │
├──────────────────────────────────────────────────────────┤
│                   Engine Layer                           │
│  SurfaceController → SurfaceRegistry + DataModelStore    │
├──────────────────────────────────────────────────────────┤
│                  Rendering Layer                         │
│  SurfaceView ← SurfaceContext                            │
├──────────────────────────────────────────────────────────┤
│                  Catalog Layer                           │
│  Catalog → CatalogItem → 18 Component builders           │
├──────────────────────────────────────────────────────────┤
│                   Model Layer                            │
│  A2UIMessage, Component, SurfaceDefinition, DataPath     │
├──────────────────────────────────────────────────────────┤
│                 Data Binding Layer                        │
│  DataModel (Combine) → DataContext → Client Functions     │
└──────────────────────────────────────────────────────────┘
```

## Layer Details

### 1. Model Layer (`Model/`)

Pure value types representing the A2UI protocol.

| Type | Role |
|------|------|
| `A2UIMessage` | Enum with 4 cases: `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface` |
| `Component` | A UI component definition: `id`, `type`, `properties` |
| `SurfaceDefinition` | Complete UI state for one surface: flat `[id: Component]` map |
| `DataPath` | Path into the data model (e.g. `/users/0/name`) |
| `UiEvent` / `UserActionEvent` | Events sent back to the AI |

### 2. Data Binding Layer (`DataBinding/`)

Reactive data store based on Combine.

| Type | Role |
|------|------|
| `DataModelProtocol` | Interface: `update(path:value:)`, `subscribe(path:)`, `getValue(path:)` |
| `InMemoryDataModel` | Implementation using nested dictionaries + `CurrentValueSubject` per path |
| `DataContext` | Scoped view of the data model for a component; resolves paths, evaluates dynamic values |
| `ClientFunction` | Protocol for pluggable functions callable from component properties |

### 3. Engine Layer (`Engine/`)

The orchestrator that processes messages and manages state.

| Type | Role |
|------|------|
| `SurfaceController` | Central hub: handles incoming messages, manages registries, routes events |
| `SurfaceRegistry` | Stores `SurfaceDefinition` per surface, provides Combine publishers for changes |
| `DataModelStore` | Stores one `DataModel` per surface |

### 4. Catalog Layer (`Catalog/`)

Component type registry with pluggable builders.

| Type | Role |
|------|------|
| `Catalog` | Collection of `CatalogItem` + `ClientFunction`, matched by `catalogId` |
| `CatalogItem` | One component type: `name` + `viewBuilder` closure |
| `BasicCatalog` | Factory that creates the default catalog with all 18 components |

### 5. Rendering Layer (`Rendering/`)

Bridges the engine to UIKit.

| Type | Role |
|------|------|
| `SurfaceView` | `UIView` subclass; subscribes to definition changes, recursively builds the view tree |
| `SurfaceContext` | Protocol bridging SurfaceView ↔ SurfaceController (definition, dataModel, catalog, events) |
| `ActionDelegate` | Optional protocol for intercepting events locally (e.g. presenting modals) |

### 6. Transport Layer (`Transport/`)

Abstracted communication with the AI backend.

| Type | Role |
|------|------|
| `A2UITransport` | Protocol: `incomingMessages`, `incomingText`, `sendAction()` |
| `A2UIStreamParser` | Extracts JSON objects from streaming text (handles markdown fences, balanced braces) |
| `A2UITransportAdapter` | Push-based wrapper around `A2UIStreamParser` |
| `MockTransport` | Testing implementation with delayed message sequences |

### 7. Facade Layer (`Facade/`)

High-level API for common use cases.

| Type | Role |
|------|------|
| `Conversation` | Wires Transport ↔ SurfaceController; exposes `state` and `events` publishers |

## Object Ownership

```
App (VC)
  ├── strong ──► SurfaceController
  │                ├── strong ──► SurfaceRegistry
  │                │                └── CurrentValueSubject per surface
  │                ├── strong ──► DataModelStore
  │                │                └── InMemoryDataModel per surface
  │                ├── strong ──► [Catalog]
  │                └── strong ──► onSubmit (PassthroughSubject)
  │
  └── strong ──► SurfaceView (via view hierarchy)
                   └── strong ──► SurfaceContext
                                    └── strong ──► SurfaceController
```

Key design decision: `SurfaceContext` holds a **strong** reference to `SurfaceController`. This ensures the engine stays alive as long as any view is rendering, without requiring the caller to manually manage the controller's lifecycle. There are no retain cycles because `SurfaceController` never references `SurfaceView` or `SurfaceContext`.

## Data Flow

### Rendering Flow (AI → Screen)

```
1. AI sends JSON        →  Transport.incomingMessages
2. Transport publishes  →  Conversation / SurfaceController.handleMessage()
3. Controller parses    →  SurfaceRegistry.updateSurface() stores definition
4. Registry publishes   →  CurrentValueSubject emits new SurfaceDefinition
5. SurfaceView receives →  rebuildUI() traverses component tree
6. Catalog builds       →  CatalogItem.viewBuilder() creates UIViews
7. DataContext resolves  →  Bindings subscribe to DataModel paths
```

### Interaction Flow (Screen → AI)

```
1. User taps button     →  Component dispatches UiEvent
2. SurfaceView routes   →  ActionDelegate check → SurfaceContext.handleUiEvent()
3. Controller forwards  →  onSubmit.send(UserActionEvent)
4. Conversation relays  →  Transport.sendAction()
5. Transport delivers   →  AI backend receives the event
```

### Data Binding Flow (bidirectional)

```
AI sends updateDataModel  →  DataModel.update(path, value)
                          →  CurrentValueSubject notifies subscribers
                          →  DataContext.resolve() → component updates UI

User edits TextField      →  DataModel.update(path, newText)
                          →  Same notification chain
                          →  Other components bound to same path update
```

## Threading Model

- **Engine operations**: All `SurfaceController.handleMessage()` calls should be on the main thread
- **Combine publishers**: Use `.receive(on: DispatchQueue.main)` before UI updates
- **Transport**: `incomingMessages` and `incomingText` can publish from any thread; the Conversation facade dispatches to main
- **DataModel**: Thread-safe via `NSRecursiveLock`
