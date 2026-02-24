# Component Reference

A2UI iOS ships with 18 built-in components organized into 4 categories.

## Core Display

### Text

Renders text content with optional style variants. Supports basic Markdown (`**bold**`).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | String or Dynamic | `""` | Text content (supports path binding) |
| `variant` | String | `"body"` | Style: `h1`-`h6`, `subtitle`, `body`, `caption` |

### Button

A tappable button that dispatches a `UserActionEvent`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | String | — | ID of the child component (typically Text) |
| `variant` | String | `"default"` | Style: `primary`, `secondary`, `danger`, `default` |
| `action` | Object | — | `{ "event": { "name": "eventName" } }` |

### Icon

Renders an icon using SF Symbols. Includes a mapping from common Material icon names.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `icon` | String | — | Icon name (Material or SF Symbol) |
| `size` | Number | `24` | Icon size in points |
| `color` | String | `"gray"` | Color name: `red`, `blue`, `green`, `orange`, `gray`, etc. |

### Divider

A horizontal line separator. No configurable properties.

## Layout

### Column

Vertical stack layout (`UIStackView` with `.vertical` axis).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | [String] | `[]` | Ordered list of child component IDs |
| `spacing` | Number | `12` | Space between children in points |
| `align` | String | `"leading"` | Alignment: `leading`, `center`, `trailing`, `fill` |

### Row

Horizontal stack layout (`UIStackView` with `.horizontal` axis).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | [String] | `[]` | Ordered list of child component IDs |
| `spacing` | Number | `8` | Space between children in points |
| `align` | String | `"center"` | Alignment: `top`, `center`, `bottom`, `fill` |

### Card

A container with rounded corners and shadow.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | String | — | ID of the single child component |

## Data-Bound Inputs

All input components support two-way data binding via the `binding` property, which is an absolute DataModel path.

### TextField

Text input field with optional multiline support.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `binding` | String | — | DataModel path (e.g. `/user/name`) |
| `label` | String | `""` | Placeholder/label text |
| `multiline` | Bool | `false` | Use multiline text view |

### CheckBox

Toggle switch with an optional label.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `binding` | String | — | DataModel path (Boolean value) |
| `label` | String | `""` | Label text |

### Slider

Numeric slider input.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `binding` | String | — | DataModel path (Number value) |
| `min` | Number | `0` | Minimum value |
| `max` | Number | `100` | Maximum value |
| `label` | String | `""` | Label text |

### ChoicePicker

Segmented control for selecting from predefined options.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `binding` | String | — | DataModel path (String value) |
| `label` | String | `""` | Label text |
| `options` | Array | `[]` | `[{ "label": "Display", "value": "key" }]` |

### DateTimeInput

Date/time picker.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `binding` | String | — | DataModel path (ISO 8601 string) |
| `mode` | String | `"date"` | Picker mode: `date`, `time`, `dateAndTime` |
| `label` | String | `""` | Label text |

## Advanced Components

### List

Scrollable list with explicit children or data-bound template rendering.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | [String] | `[]` | Static child component IDs |
| `binding` | String | — | DataModel path to an array for template rendering |
| `template` | String | — | Component ID to repeat for each array item |

### Tabs

Tab switcher with content panels.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | [String] | `[]` | Child component IDs (one per tab) |
| `labels` | [String] | `[]` | Tab labels |

### Modal

Placeholder for modal dialogs. Content is built by `SurfaceView` and presented via `ActionDelegate`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | String | — | Content component ID |
| `title` | String | `""` | Modal title |

### Image

Loads and displays an image from a URL.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `url` | String | — | Image URL |
| `width` | Number | — | Fixed width (optional) |
| `height` | Number | — | Fixed height (optional) |
| `contentMode` | String | `"fit"` | `fit` or `fill` |

### AudioPlayer

Basic audio playback with play/pause controls.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `url` | String | — | Audio file URL |

### Video

Video playback with basic controls.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `url` | String | — | Video file URL |

## Adding Custom Components

Register a new component by creating a `CatalogItem` and extending the catalog:

```swift
let myComponent = CatalogItem(name: "MyWidget") { context in
    let label = UILabel()
    label.text = context.data["title"] as? String ?? "Default"
    return label
}

let extendedCatalog = BasicCatalog.create().copyWith(newItems: [myComponent])
let controller = SurfaceController(catalogs: [extendedCatalog])
```
