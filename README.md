# Node Freezer

**Freeze / unfreeze any node with one click — stops scripts, rendering, physics, collisions, and audio\.**

Node Freezer is a Godot editor plugin that lets you instantly “freeze” or “unfreeze” any node in your scene, just like toggling visibility\. When frozen, the node and all its descendants completely stop working at runtime — scripts no longer execute, visuals are hidden, collisions are disabled, and audio pauses — while the node structure remains intact in the scene tree and can be unfrozen at any time\.

---

## ✨ Features

- **Editor toolbar button** — one\-click freeze/unfreeze with clear status icons\.

    - Unfrozen: warm orange sun ☀️

    - Frozen: bright cyan snowflake ❄️

- **Recursive by default** — freezing a parent freezes all its children\.

- **Completely stops runtime logic:**

    - Scripts: `process_mode` set to `DISABLED`, halting `_process`, `_physics_process`, `_input`, etc\.

    - Rendering: all `CanvasItem` children are hidden\.

    - Physics \& collisions: `CollisionObject2D` gets `disable_mode = REMOVE`, fully removed from the physics simulation\.

    - Audio: `AudioStreamPlayer` nodes are paused\.

- **Full undo/redo support** — every freeze/unfreeze action can be undone with `Ctrl + Z`\.

- **State persistence** — frozen state and original values are stored in node metadata and saved with the scene\.

- **Safe \& non\-destructive** — nodes are never removed from the scene tree; `owner` relationships, signal connections, and scene structure remain unchanged\.

---

## 📦 Installation

1. Open the **AssetLib** tab in the Godot editor, search for **Node Freezer**, and install\.

2. Or manually download the ZIP, extract it, and place the `addons/node_freezer` folder into your project root\.

3. Go to **Project → Project Settings → Plugins**, find **Node Freezer**, and enable it\.

4. A new icon button will appear in the top toolbar\.

---

## 🎮 Usage

1. Select one or more nodes in the Scene tree \(hold `Ctrl` for multi\-select\)\.

2. Click the **Node Freezer** button in the top toolbar:

    - **Orange sun** icon → currently unfrozen; click to freeze\.

    - **Cyan snowflake** icon → currently frozen; click to unfreeze\.

3. Frozen nodes stop completely at runtime; unfreezing restores their original state\.

4. Press `Ctrl + Z` to undo the last action\.

---

## ⚙️ Compatibility

- **Godot version**: Godot 4\.5 and above \(tested on Godot 4\.7\.1\)\.

- **Platform**: All platforms supported by the Godot editor\.

- **License**: MIT\.

---

## 📝 Notes

- Freezing does **not** remove the node from the scene tree\. The node remains visible, selectable, and saved\.

- If the node contains an `AudioStreamPlayer`, unfreezing resumes playback from the paused position, not from the beginning\.

- If the node itself uses a `@tool` script, its editor `_process` will also stop when frozen — this is expected behavior\.

---

## 🔗 Links

- Source code / Issue tracker: \[[GitHub repository URL](https://github.com/jasper-xu/godot-node-freezer)\]

- License: [MIT](https://opensource.org/licenses/MIT)

