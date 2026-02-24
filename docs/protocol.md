# A2UI Protocol v0.9 — Message Format

## Overview

The A2UI protocol defines 4 message types for managing dynamic UI surfaces. Messages are JSON objects sent from the AI backend to the client.

## Message Types

### 1. CreateSurface

Creates a new UI surface (or reinitializes an existing one).

```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "weather-ui",
    "catalogId": "com.google.genui.basic",
    "sendDataModel": false
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `surfaceId` | String | Yes | Unique identifier for this surface |
| `catalogId` | String | Yes | Which component catalog to use |
| `sendDataModel` | Bool | No | If true, attach data model to transport |

### 2. UpdateComponents

Adds or updates components in an existing surface. Components are merged into the surface's flat map — unchanged components are preserved.

```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "weather-ui",
    "components": [
      {
        "id": "root",
        "component": "Column",
        "children": ["title", "content"]
      },
      {
        "id": "title",
        "component": "Text",
        "text": "Weather Report",
        "variant": "h3"
      },
      {
        "id": "content",
        "component": "Text",
        "text": "Sunny, 26°C",
        "variant": "body"
      }
    ]
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `surfaceId` | String | Yes | Target surface |
| `components` | Array | Yes | Component definitions to add/update |

Each component has:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | String | Yes | Unique component identifier |
| `component` | String | Yes | Component type name (e.g. "Text", "Button") |
| *(other)* | Any | No | Type-specific properties |

### 3. UpdateDataModel

Sets or updates a value in the surface's reactive data model.

```json
{
  "version": "v0.9",
  "updateDataModel": {
    "surfaceId": "weather-ui",
    "path": "/user/name",
    "value": "Alice"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `surfaceId` | String | Yes | Target surface |
| `path` | String | Yes | Absolute path in the data model |
| `value` | Any | No | The value to set (null to clear) |

### 4. DeleteSurface

Removes a surface and releases its resources.

```json
{
  "version": "v0.9",
  "deleteSurface": {
    "surfaceId": "weather-ui"
  }
}
```

## Component Tree Structure

Components form a **flat map** keyed by `id`. Parent-child relationships are expressed through property references:

```json
{
  "components": [
    { "id": "root", "component": "Column", "children": ["header", "body"] },
    { "id": "header", "component": "Text", "text": "Hello" },
    { "id": "body", "component": "Card", "child": "body_content" },
    { "id": "body_content", "component": "Text", "text": "World" }
  ]
}
```

- `children` (Array of Strings): ordered list of child component IDs
- `child` (String): single child component ID
- Rendering always starts from the component with `id: "root"`

## Dynamic Values

Property values can be:

- **Literal**: `"text": "Hello"` — static value
- **Path binding**: `"text": { "path": "/user/name" }` — resolves from DataModel, updates reactively
- **Function call**: `"text": { "function": "formatDate", "args": { "value": { "path": "/date" } } }` — evaluated via client functions

## User Events (Client → AI)

When a user interacts with a component (e.g. button tap), a `UserActionEvent` is sent back:

```json
{
  "version": "v0.9",
  "event": {
    "name": "submit_form",
    "surfaceId": "form-ui"
  }
}
```

## Message Buffering

If `updateComponents` or `updateDataModel` arrives before `createSurface` for the same `surfaceId`, the engine buffers them and replays after the surface is created. Buffer timeout defaults to 60 seconds.
