# Data Binding System

## Overview

A2UI uses a path-based reactive data model powered by Combine. Each surface has its own isolated `DataModel` instance. UI components can read, write, and subscribe to values at any path in the model, enabling automatic two-way synchronization.

## DataPath

A `DataPath` represents a location in the nested data tree.

```swift
DataPath("/user/name")          // absolute path → segments: ["user", "name"]
DataPath("/hotels/0/stars")     // array index support
DataPath.root                   // the root "/" path
```

Paths support:
- **Joining**: `parent.join(child)` — combines two paths
- **Prefix checking**: `path.starts(with: other)`
- **Navigation**: `path.dirname` (parent), `path.basename` (last segment)

## DataModel

The `DataModelProtocol` defines 3 operations:

```swift
public protocol DataModelProtocol: AnyObject {
    func update(path: DataPath, value: Any?)
    func subscribe(path: DataPath) -> AnyPublisher<Any?, Never>
    func getValue(path: DataPath) -> Any?
}
```

### Three-Way Notification

When a value at path `/a/b/c` is updated, `InMemoryDataModel` notifies:

1. **Exact match**: subscribers at `/a/b/c` receive the new value
2. **Ancestor bubble**: subscribers at `/a/b` and `/a` receive their subtree (because a child changed)
3. **Descendant propagation**: subscribers at `/a/b/c/d` receive their resolved sub-value (because a parent was overwritten)

This ensures that components at any nesting level stay in sync.

## DataContext

`DataContext` provides a scoped, reactive interface for components to resolve dynamic property values. It wraps a `DataModel` with a base path and available functions.

### Resolving Dynamic Values

Component properties can contain 3 types of values:

#### 1. Literal Values

```json
{ "text": "Hello, World!" }
```

Resolved as-is. Returns `Just(value).eraseToAnyPublisher()`.

#### 2. Path Bindings

```json
{ "text": { "path": "/user/name" } }
```

Subscribes to the DataModel at the resolved path. Emits updates whenever the value changes.

#### 3. Function Calls

```json
{
  "text": {
    "function": "formatCurrency",
    "args": {
      "value": { "path": "/order/total" },
      "currency": "USD"
    }
  }
}
```

Arguments are resolved recursively (can be literals, paths, or nested function calls), then the function is executed.

### Nested Contexts for Lists

When rendering a List with data-bound templates, each item gets a child `DataContext` scoped to its array index:

```
Root DataContext:  basePath = /
  Item 0 context:  basePath = /items/0
  Item 1 context:  basePath = /items/1
  Item 2 context:  basePath = /items/2
```

Relative paths in the template resolve against the item's base path.

## Client Functions

12 built-in functions available in any component property:

### Validation Functions

| Name | Arguments | Returns |
|------|-----------|---------|
| `required` | `value` | Error string if empty, nil if valid |
| `regex` | `value`, `pattern` | Error string if no match |
| `length` | `value`, `min`, `max` | Error string if out of range |
| `numeric` | `value`, `min`, `max` | Error string if not numeric or out of range |
| `email` | `value` | Error string if invalid email format |

### Formatting Functions

| Name | Arguments | Returns |
|------|-----------|---------|
| `formatString` | `template`, `values` | Formatted string |
| `formatNumber` | `value`, `decimals` | Formatted number string |
| `formatCurrency` | `value`, `currency` | Currency-formatted string |
| `formatDate` | `value`, `format` | Formatted date string |

### Logic Functions

| Name | Arguments | Returns |
|------|-----------|---------|
| `and` | `a`, `b` | Boolean AND |
| `or` | `a`, `b` | Boolean OR |
| `not` | `value` | Boolean NOT |

## Two-Way Binding Example

When an AI sends this:

```json
{ "id": "nameField", "component": "TextField", "binding": "/user/name" }
```

The flow is:

```
DataModel /user/name = "Alice"
      │
      ▼  subscribe
TextField displays "Alice"
      │
      ▼  user types "Bob"
DataModel.update(/user/name, "Bob")
      │
      ▼  notify all subscribers at /user/name
Any Text component with { "path": "/user/name" } updates to "Bob"
```
