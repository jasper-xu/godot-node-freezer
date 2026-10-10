@tool
extends EditorPlugin

const ICON_FREEZE: Texture2D = preload("res://addons/node_freezer/icons/freeze.svg")
const ICON_UNFREEZE: Texture2D = preload("res://addons/node_freezer/icons/unfreeze.svg")

# Metadata keys
const META_FROZEN := "_node_freezer_frozen"
const META_ORIG_PROCESS := "_node_freezer_orig_process_mode"
const META_ORIG_VISIBLE := "_node_freezer_orig_visible"
const META_ORIG_DISABLE := "_node_freezer_orig_disable_mode"
const META_ORIG_PAUSED := "_node_freezer_orig_stream_paused"
const META_PROCESSING := "_node_freezer_processing"

var _button: Button = null
var _undo_redo: EditorUndoRedoManager


func _enter_tree() -> void:
	_undo_redo = get_undo_redo()

	# Clean up any stale button first (prevents duplicate loading)
	_cleanup_button()

	_button = Button.new()
	_button.toggle_mode = true
	_button.icon = ICON_UNFREEZE
	_button.add_theme_constant_override("icon_max_width", 24)
	_button.custom_minimum_size = Vector2(28, 28)
	_button.tooltip_text = "Freeze/unfreeze selected nodes\n(stops scripts, rendering, physics, collision, and audio)"
	_button.pressed.connect(_on_button_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)

	var selection := get_editor_interface().get_selection()
	if not selection.selection_changed.is_connected(_refresh_button_state):
		selection.selection_changed.connect(_refresh_button_state)
	_refresh_button_state()


func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if selection and selection.selection_changed.is_connected(_refresh_button_state):
		selection.selection_changed.disconnect(_refresh_button_state)

	_cleanup_button()


func _cleanup_button() -> void:
	if _button and is_instance_valid(_button):
		if _button.pressed.is_connected(_on_button_pressed):
			_button.pressed.disconnect(_on_button_pressed)
		remove_control_from_container(CONTAINER_TOOLBAR, _button)
		_button.queue_free()
	_button = null


# ----------------------------------------------------------------
# Button state refresh
# ----------------------------------------------------------------

func _refresh_button_state() -> void:
	if not _button or not is_instance_valid(_button):
		return

	var nodes := get_editor_interface().get_selection().get_selected_nodes()
	if nodes.is_empty():
		_button.disabled = true
		_button.button_pressed = false
		_button.icon = ICON_UNFREEZE
		return

	_button.disabled = false

	var all_frozen := true
	for n in nodes:
		if not _is_frozen(n):
			all_frozen = false
			break

	_button.button_pressed = all_frozen
	_button.icon = ICON_FREEZE if all_frozen else ICON_UNFREEZE


func _is_frozen(node: Node) -> bool:
	return node.has_meta(META_FROZEN) and node.get_meta(META_FROZEN) == true


# ----------------------------------------------------------------
# Button pressed: freeze / unfreeze
# ----------------------------------------------------------------

func _on_button_pressed() -> void:
	if not _button or not is_instance_valid(_button):
		return

	var nodes := get_editor_interface().get_selection().get_selected_nodes()
	if nodes.is_empty():
		return

	var do_freeze := _button.button_pressed

	_undo_redo.create_action("Freeze Nodes" if do_freeze else "Unfreeze Nodes")
	for n in nodes:
		_register_recursive(n, do_freeze)
	_undo_redo.commit_action()

	_refresh_button_state()


func _register_recursive(node: Node, freeze: bool) -> void:
	if node.has_meta(META_PROCESSING):
		return
	node.set_meta(META_PROCESSING, true)

	var already_frozen := _is_frozen(node)

	if freeze and not already_frozen:
		_register_freeze(node)
	elif not freeze and already_frozen:
		_register_unfreeze(node)

	for child in node.get_children():
		_register_recursive(child, freeze)

	node.remove_meta(META_PROCESSING)


# ----------------------------------------------------------------
# Register freeze operation (supports undo/redo)
# ----------------------------------------------------------------

func _register_freeze(node: Node) -> void:
	var orig_process: int = node.process_mode
	var is_canvas := node is CanvasItem
	var is_collision := node is CollisionObject2D
	var is_audio := (node is AudioStreamPlayer
			or node is AudioStreamPlayer2D
			or node is AudioStreamPlayer3D)

	var orig_visible := true
	var orig_disable := 0
	var orig_paused := false
	if is_canvas:
		orig_visible = node.visible
	if is_collision:
		orig_disable = node.disable_mode
	if is_audio:
		orig_paused = node.stream_paused

	# --- DO: perform freeze ---
	_undo_redo.add_do_method(node, "set_meta", META_FROZEN, true)
	_undo_redo.add_do_method(node, "set_meta", META_ORIG_PROCESS, orig_process)
	_undo_redo.add_do_property(node, "process_mode", Node.PROCESS_MODE_DISABLED)

	if is_canvas:
		_undo_redo.add_do_method(node, "set_meta", META_ORIG_VISIBLE, orig_visible)
		_undo_redo.add_do_property(node, "visible", false)
	if is_collision:
		_undo_redo.add_do_method(node, "set_meta", META_ORIG_DISABLE, orig_disable)
		_undo_redo.add_do_property(node, "disable_mode", CollisionObject2D.DISABLE_MODE_REMOVE)
	if is_audio:
		_undo_redo.add_do_method(node, "set_meta", META_ORIG_PAUSED, orig_paused)
		_undo_redo.add_do_property(node, "stream_paused", true)

	# --- UNDO: undo freeze ---
	_undo_redo.add_undo_property(node, "process_mode", orig_process)
	_undo_redo.add_undo_method(node, "remove_meta", META_FROZEN)
	_undo_redo.add_undo_method(node, "remove_meta", META_ORIG_PROCESS)

	if is_canvas:
		_undo_redo.add_undo_property(node, "visible", orig_visible)
		_undo_redo.add_undo_method(node, "remove_meta", META_ORIG_VISIBLE)
	if is_collision:
		_undo_redo.add_undo_property(node, "disable_mode", orig_disable)
		_undo_redo.add_undo_method(node, "remove_meta", META_ORIG_DISABLE)
	if is_audio:
		_undo_redo.add_undo_property(node, "stream_paused", orig_paused)
		_undo_redo.add_undo_method(node, "remove_meta", META_ORIG_PAUSED)


# ----------------------------------------------------------------
# Register unfreeze operation (supports undo/redo)
# ----------------------------------------------------------------

func _register_unfreeze(node: Node) -> void:
	var orig_process: int = node.get_meta(META_ORIG_PROCESS)
	var is_canvas := node is CanvasItem
	var is_collision := node is CollisionObject2D
	var is_audio := (node is AudioStreamPlayer
			or node is AudioStreamPlayer2D
			or node is AudioStreamPlayer3D)

	var orig_visible := true
	var orig_disable := 0
	var orig_paused := false
	if is_canvas and node.has_meta(META_ORIG_VISIBLE):
		orig_visible = node.get_meta(META_ORIG_VISIBLE)
	if is_collision and node.has_meta(META_ORIG_DISABLE):
		orig_disable = node.get_meta(META_ORIG_DISABLE)
	if is_audio and node.has_meta(META_ORIG_PAUSED):
		orig_paused = node.get_meta(META_ORIG_PAUSED)

	var frozen_process: int = node.process_mode
	var frozen_visible := true
	var frozen_disable := 0
	var frozen_paused := false
	if is_canvas:
		frozen_visible = node.visible
	if is_collision:
		frozen_disable = node.disable_mode
	if is_audio:
		frozen_paused = node.stream_paused

	# --- DO: perform unfreeze ---
	_undo_redo.add_do_property(node, "process_mode", orig_process)
	_undo_redo.add_do_method(node, "remove_meta", META_FROZEN)
	_undo_redo.add_do_method(node, "remove_meta", META_ORIG_PROCESS)

	if is_canvas:
		_undo_redo.add_do_property(node, "visible", orig_visible)
		_undo_redo.add_do_method(node, "remove_meta", META_ORIG_VISIBLE)
	if is_collision:
		_undo_redo.add_do_property(node, "disable_mode", orig_disable)
		_undo_redo.add_do_method(node, "remove_meta", META_ORIG_DISABLE)
	if is_audio:
		_undo_redo.add_do_property(node, "stream_paused", orig_paused)
		_undo_redo.add_do_method(node, "remove_meta", META_ORIG_PAUSED)

	# --- UNDO: undo unfreeze ---
	_undo_redo.add_undo_property(node, "process_mode", frozen_process)
	_undo_redo.add_undo_method(node, "set_meta", META_FROZEN, true)
	_undo_redo.add_undo_method(node, "set_meta", META_ORIG_PROCESS, orig_process)

	if is_canvas:
		_undo_redo.add_undo_property(node, "visible", frozen_visible)
		_undo_redo.add_undo_method(node, "set_meta", META_ORIG_VISIBLE, orig_visible)
	if is_collision:
		_undo_redo.add_undo_property(node, "disable_mode", frozen_disable)
		_undo_redo.add_undo_method(node, "set_meta", META_ORIG_DISABLE, orig_disable)
	if is_audio:
		_undo_redo.add_undo_property(node, "stream_paused", frozen_paused)
		_undo_redo.add_undo_method(node, "set_meta", META_ORIG_PAUSED, orig_paused)
