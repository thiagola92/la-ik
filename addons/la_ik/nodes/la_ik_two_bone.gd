@tool
class_name LaIKTwoBone
extends LaIK


@export var bone_one: LaBone:
	set(b):
		_undo_modifications()
		_stop_listen_bone(bone_one)
		bone_one = b
		_start_listen_bone(bone_one)
		queue_redraw()

@export var bone_two: LaBone:
	set(b):
		_undo_modifications()
		_stop_listen_bone(bone_two)
		bone_two = b
		_start_listen_bone(bone_two)
		queue_redraw()

@export var target: Node2D

## Flip the direction which the bone bend to.
@export var flip_bend: bool = false

@export_group("Contraints", "constraint_")

@export var constraint_enabled: bool = false:
	set(e):
		constraint_enabled = e
		queue_redraw()

## Show a line were [member bone_two] and [member target] can meet.
@export var constraint_visible: bool = true:
	set(v):
		constraint_visible = v
		queue_redraw()

## [b]Note[/b]: This distance is unaffected by scaling.
@export var constraint_min_distance: float = 0:
	set(d):
		if d >= 0 and d <= constraint_max_distance:
			constraint_min_distance = d

## [b]Note[/b]: This distance is unaffected by scaling.
@export var constraint_max_distance: float = 0:
	set(d):
		if d >= 0 and d >= constraint_min_distance:
			constraint_max_distance = d


func _draw() -> void:
	_draw_gizmo()


func _start_listen_bone(bone: LaBone) -> void:
	if not bone:
		return
	
	# The first child bone is used to know where the bone is looking at,
	# so we need to listen if the first child bone change.
	if not bone.child_order_changed.is_connected(queue_redraw):
		bone.child_order_changed.connect(queue_redraw)
	
	# If bone move, redraw the constraints position.
	if not bone.transform_changed.is_connected(queue_redraw):
		bone.transform_changed.connect(queue_redraw)
	
	# If bone is removed from tree, redraw constraints.
	if not bone.tree_exiting.is_connected(queue_redraw):
		bone.tree_exiting.connect(queue_redraw)
	
	# If bone is about to be deleted, probably need to set some field to null.
	if not bone.tree_exiting.is_connected(_forget_bone.bind(bone)):
		bone.tree_exiting.connect(_forget_bone.bind(bone))
	
	# Update contraint in case child bone move.
	bone.child_bone_changing.connect(_listen_child_bone_changes)
	_listen_child_bone_changes(null, bone.get_child_bone())


func _listen_child_bone_changes(previous_child_bone: LaBone, current_child_bone: LaBone) -> void:
	if previous_child_bone:
		if previous_child_bone.transform_changed.is_connected(queue_redraw):
			previous_child_bone.transform_changed.disconnect(queue_redraw)
	
	if current_child_bone:
		if not current_child_bone.transform_changed.is_connected(queue_redraw):
			current_child_bone.transform_changed.connect(queue_redraw)


# Forget bone only if it's being deleted (to avoid acessing freed object).[br]
# Used when leaving the tree because we don't know if it's being deleted or stored for later.
func _forget_bone(bone: LaBone) -> void:
	if not bone.is_queued_for_deletion():
		return
	
	if bone == bone_one:
		bone_one = null
	elif bone == bone_two:
		bone_two = null


func _stop_listen_bone(bone: LaBone) -> void:
	if not bone:
		return
	
	if bone.child_order_changed.is_connected(queue_redraw):
		bone.child_order_changed.disconnect(queue_redraw)
	
	if bone.transform_changed.is_connected(queue_redraw):
		bone.transform_changed.disconnect(queue_redraw)
	
	if bone.tree_exiting.is_connected(queue_redraw):
		bone.tree_exiting.disconnect(queue_redraw)
	
	if bone.tree_exiting.is_connected(_forget_bone.bind(bone)):
		bone.tree_exiting.disconnect(_forget_bone.bind(bone))
	
	if bone.child_bone_changing.is_connected(_listen_child_bone_changes):
		bone.child_bone_changing.disconnect(_listen_child_bone_changes)


func _undo_modifications() -> void:
	if bone_one:
		bone_one.restore_pose()
	
	if bone_two:
		bone_two.restore_pose()


func _apply_modifications(_delta: float) -> void:
	if not enabled:
		return
	
	if not target or not target.is_inside_tree():
		return
	
	if not bone_one or not bone_one.is_inside_tree():
		return
	
	if not bone_two or not bone_two.is_inside_tree():
		return
	
	bone_one.cache_pose()
	bone_two.cache_pose()
	bone_one.is_pose_modified = true
	bone_two.is_pose_modified = true
	
	var target_distance: float = bone_one.global_position.distance_to(target.global_position)
	
	if constraint_enabled:
		# Zero means that there is no distance contraint.
		if constraint_min_distance > 0 and target_distance < constraint_min_distance:
			target_distance = constraint_min_distance
		
		# Zero means that there is no distance contraint.
		if constraint_max_distance > 0 and target_distance > constraint_max_distance:
			target_distance = constraint_max_distance
	
	var bone_one_length: float = bone_one.get_bone_length()
	var bone_two_length: float = bone_two.get_bone_length()
	var out_of_range: bool = target_distance > bone_one_length + bone_two_length
	var angle_to_x_axis: float = (target.global_position - bone_one.global_position).angle()
	var same_sign: bool = bone_one.global_scale.sign().x == bone_one.global_scale.sign().y
	
	# Easiest case, target is out of range.
	if out_of_range:
		# Any angle scaled by -1 will give a mirror angle in that axis,
		# now any operation over the angle needs to flip sign to give a mirror angle.
		# Example: (45º + 5º) is mirror to (135º - 5º)
		if same_sign:
			bone_one.global_rotation = angle_to_x_axis - bone_one.get_bone_angle()
			bone_two.global_rotation = angle_to_x_axis - bone_two.get_bone_angle()
		else:
			bone_one.global_rotation = angle_to_x_axis + bone_one.get_bone_angle()
			bone_two.global_rotation = angle_to_x_axis + bone_two.get_bone_angle()
		
		return
	
	var angle_0: float = acos(
		(target_distance ** 2 + bone_one_length ** 2 - bone_two_length ** 2) / (2 * target_distance * bone_one_length)
	)
	
	var angle_1: float = acos(
		(bone_two_length ** 2 + bone_one_length ** 2 - target_distance ** 2) / (2 * bone_two_length * bone_one_length)
	)
	
	# Cannot solve for this angles! Do nothing to avoid setting the rotation to NAN.
	if is_nan(angle_0) or is_nan(angle_1):
		return
	
	if flip_bend:
		angle_0 = -angle_0
		angle_1 = -angle_1
	
	# Global rotation is affected by scale changes.
	if same_sign:
		bone_one.global_rotation = angle_to_x_axis - angle_0 - bone_one.get_bone_angle()
	else:
		bone_one.global_rotation = angle_to_x_axis + angle_0 + bone_one.get_bone_angle()
	
	# Local rotation is unaffected by scale changes.
	bone_two.rotation = PI - angle_1 - bone_two.get_bone_angle() + bone_one.get_bone_angle()


func _draw_gizmo() -> void:
	if not constraint_visible:
		return
	
	if not bone_one:
		return
	
	if not bone_two:
		return
	
	if not target:
		return
	
	if not EditorInterface.has_method("get_editor_settings"):
		queue_redraw()
		return
	
	draw_set_transform(bone_one.global_position, 0)
	
	var min_distance: float = 0
	var max_distance: float = bone_one.get_bone_length() + bone_two.get_bone_length()
	
	if constraint_enabled:
		min_distance = constraint_min_distance
		
		# Zero means that there is no distance contraint.
		if constraint_max_distance > 0:
			max_distance = constraint_max_distance
	
	var editor_settings = EditorInterface.get_editor_settings()
	var bone_ik_color: Color = editor_settings.get_setting("editors/2d/bone_ik_color")
	var target_direction: Vector2 = bone_one.global_position.direction_to(target.global_position)
	var min_position: Vector2 = target_direction * min_distance
	var max_position: Vector2 = target_direction * max_distance
	
	draw_line(min_position, max_position, bone_ik_color, 2.0)
