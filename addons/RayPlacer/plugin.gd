@tool
extends EditorPlugin

enum Mode { IDLE, RAYCASTING }

var mode: Mode = Mode.IDLE

func _handles(object: Object) -> bool:
	return object is Node3D

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_transformable_selected_nodes()
	if selected_nodes.size() != 1 or not selected_nodes[0] is Node3D:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var selected_node: Node3D = selected_nodes[0] as Node3D
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	if mode == Mode.IDLE:
		if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.is_pressed() \
			and Input.is_key_pressed(KEY_ALT):
			undo_redo.create_action("Move node", UndoRedo.MERGE_DISABLE, EditorInterface.get_edited_scene_root())
			undo_redo.add_undo_property(selected_node, "global_transform", selected_node.global_transform)
			mode = Mode.RAYCASTING
	if mode == Mode.RAYCASTING:
		if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.is_released():
			undo_redo.add_do_property(selected_node, "global_transform", selected_node.global_transform)
			undo_redo.commit_action(false)
			mode = Mode.IDLE
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event is InputEventMouse:
			var mousepos := EditorInterface.get_editor_viewport_3d().get_mouse_position()
			var origin := camera.project_ray_origin(mousepos)
			var end := origin + camera.project_ray_normal(mousepos) * camera.far
			var query := PhysicsRayQueryParameters3D.create(origin, end, 0xFFFFFFFF, _get_rids(selected_node))
			var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit:
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			var up: Vector3 = hit["normal"]
			var forward: Vector3 = selected_node.global_basis.x.cross(up)
			if forward.dot(selected_node.global_basis.z) > 0.0:
				forward *= -1.0
			selected_node.global_transform = Transform3D(Basis.looking_at(forward, up), hit["position"])
			return EditorPlugin.AFTER_GUI_INPUT_STOP
				
	return EditorPlugin.AFTER_GUI_INPUT_PASS

static func _get_rids(node: Node) -> Array[RID]:
	var result: Array[RID] = []
	for c in node.get_children():
		result.append_array(_get_rids(c))
	if node is CollisionObject3D:
		result.append(node.get_rid())
	return result
