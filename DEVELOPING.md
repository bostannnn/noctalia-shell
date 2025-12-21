# Developing Noctalia Shell (Fork)

This repo is a Quickshell QML codebase. To keep it maintainable, new features should follow the same patterns for:

- where state/side-effects live (`Services/`)
- where UI lives (`Modules/` and `Widgets/`)
- how windows are created (layer-shell `PanelWindow`s)
- how IPC is exposed (`Services/Control/IPCService.qml`)

## Mental Model

- `shell.qml` is the entrypoint and scene graph root (`ShellRoot`).
- `Services/*` are singletons (or service-ish Items) that own state, persistence, and side-effects (processes, IPC, filesystem, compositor queries).
- `Modules/*` are UI “features” placed into the scene graph (bar, panels, notifications, overview, etc).
- `Widgets/*` are reusable UI primitives (`NButton`, `NText`, etc) and reusable infrastructure components used by modules.
- `Commons/*` are shared singletons/utilities (`Settings`, `Style`, `Color`, `Logger`) and generic helpers (e.g. `JsonProcess`).

## Adding A New Feature (Checklist)

1. Decide whether it’s a **service**, a **module**, or a **widget**:
   - **Service**: persistent state, compositor integration, background tasks, polling, disk IO.
   - **Module**: a visible feature (panel, overlay, window, bar feature) that wires existing services to UI.
   - **Widget**: reusable UI control that should be used across multiple modules.
2. Use `Settings.data.*` for persistent configuration; keep transient state in a service singleton.
3. If you need a new layer-shell window, use `Widgets/NLayerShellWindow.qml`.
4. If you need a new IPC target, add it to `Services/Control/IPCService.qml` (do not scatter `IpcHandler`s in modules).
5. Prefer `Widgets/N*` components over raw `Text`, `Button`, etc to keep styling consistent.

## Layer-Shell Windows (Unification)

Use `Widgets/NLayerShellWindow.qml` for any `PanelWindow` that sets `WlrLayershell.*`.

- It standardizes the properties:
  - `layerNamespace`
  - `layerShellLayer`
  - `layerShellKeyboardFocus`
  - `layerShellExclusionMode`
- It defaults to `color: Color.transparent`.

Guidelines:

- **Namespaces** should be stable and unique per screen when needed: `noctalia-<feature>-<screenName>`.
- Prefer `ExclusionMode.Ignore` unless you intentionally reserve space.
- Use `WlrLayer.Overlay` only for true overlays that must be above everything.

## IPC (Unification)

All IPC targets are centralized in `Services/Control/IPCService.qml`.

To add a new IPC API:

1. Add an `IpcHandler { target: "<name>" ... }` block there.
2. Keep handler methods small; call into an existing service/module API.
3. Avoid window-creation logic in IPC handlers; instead toggle a service state (e.g. `OverviewService.isOpen`).

Quickshell CLI usage depends on your version. Common pattern:

- `quickshell ipc call <target> <function> [args...]`

## Running JSON Commands (Unification)

If you need to run a command that returns JSON (e.g. `hyprctl ... -j`, `swaymsg -t ... -r`), use `Commons/JsonProcess.qml` instead of repeating:

- `Process`
- `SplitParser`
- `accumulatedOutput`
- `JSON.parse(...)`

Example:

```qml
JsonProcess {
  id: getSomething
  command: ["hyprctl", "monitors", "-j"]
  logTag: "MyService"
  onJsonReady: data => { /* use parsed data */ }
}
```

## Naming Conventions

- Avoid generic QML type names like `Overview.qml` unless it is truly the only “overview”.
- Prefer descriptive names:
  - `WorkspaceOverview` (Hyprland)
  - `WallpaperOverview` (Niri)
- For new windows, prefer `*Window.qml` naming for layer-shell windows and `*Service.qml` for singleton state.

## Styling Conventions

- Use `Commons/Style.qml` spacing and sizes (`Style.marginM`, `Style.radiusL`, `Style.barHeight`).
- Use `Commons/Color.qml` palette (`Color.mSurface`, `Color.mOutline`, etc).
- Prefer `Widgets/NText.qml` instead of raw `Text` for consistent font, color, and scaling.

## Lists, Delegates, and Compatibility

This repo runs on a variety of Quickshell/Qt versions. To avoid fragile behavior:

- Prefer `Widgets/NListView.qml` over raw `ListView` when you need scrollbars.
- Prefer explicit delegate properties:
  - `delegate: Item { required property var modelData; required property int index; ... }`
- Avoid relying on implicit `index`/role name injection in nested delegates (especially inside per-screen delegates).

### QML JavaScript Compatibility

In QML JS blocks, avoid modern JS syntax that may not be supported on all runtimes:

- Avoid: arrow functions (`=>`), optional chaining (`?.`), nullish coalescing (`??`), `const`/`let`, `.includes(...)`.
- Prefer: `function(...) {}`, `var`, explicit null checks, and `indexOf(...) !== -1`.

## Taskwarrior Backend Notes

`TaskService.modifyTask()` builds argv tokens for `task ... modify`.

- Attribute assignment uses `key:value` tokens (e.g. `project:Work`, `due:tomorrow`).
- Tag add/remove uses `+tag` / `-tag` (no colon). Do not emit `+:tag` / `-:tag`.

If you previously ran a buggy build that emitted `+:tag` / `-:tag`, affected tasks may have those strings embedded in their descriptions. A cleanup helper is available:

- `python3 Bin/fix_taskwarrior_legacy_colon_tags.py` (dry-run)
- `python3 Bin/fix_taskwarrior_legacy_colon_tags.py --apply` (apply)

## Where To Put Things

- New **panel**: `Modules/Panels/<Name>/...` + register via existing `PanelService` patterns.
- New **bar widget**: `Modules/Bar/Widgets/<Name>.qml` + register in `Services/UI/BarWidgetRegistry.qml`.
- New **desktop widget**: `Modules/DesktopWidgets/Widgets/<Name>.qml` + register in `Services/UI/DesktopWidgetRegistry.qml`.

## Release / PR Checklist (Consistency)

Before merging a feature, quickly scan for new inconsistencies:

### 1) No new raw layer-shell windows

There should be **no new** direct `WlrLayershell.*` usage outside `Widgets/NLayerShellWindow.qml`.

- `rg -n "WlrLayershell\\." Modules Services Widgets`

There should also be **no new** `PanelWindow` that is meant for layer-shell; use `NLayerShellWindow` instead.

- `rg -n "\\bPanelWindow\\s*\\{|sourceComponent:\\s*PanelWindow" Modules Services`

### 2) IPC stays centralized

All `IpcHandler` blocks should live in `Services/Control/IPCService.qml`.

- `rg -n "\\bIpcHandler\\b" Modules Services | head`

If you added a feature toggle, expose it by toggling service state (don’t create windows from IPC handlers).

### 3) JSON process parsing stays unified

If a command returns JSON, use `Commons/JsonProcess.qml`.

- `rg -n "accumulatedOutput|JSON\\.parse\\(" Services/Compositor Services/UI`

### 4) UI styling uses the design system

Prefer `Widgets/N*` components and `Commons/Style.qml` + `Commons/Color.qml`:

- Avoid raw `Text {` unless it is a special case.
- Avoid hardcoded colors; use `Color.*` and `Qt.alpha(...)`.
- Avoid magic sizes; use `Style.*` or scale with `Style.uiScaleRatio`.

### 5) Naming avoids ambiguity

Avoid generic names like `Overview.qml` unless there is only one “overview” concept.

- Prefer `WorkspaceOverview`, `WallpaperOverview`, `*Service`, `*Window`.
