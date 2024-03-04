@tool
class_name LaIKLookAt
extends LaIK


## The bone that will receive modifications to look at [member target].[br][br]
## [b]Note[/b]: It uses [member LaBone.bone_angle] to know where the bone is looking at.
@export var bone: LaBone:
	set(b):
		_undo_modifications()
		_stop_listen_bone()
		bone = b
		_start_listen_bone()
		queue_redraw()

## The node which [member bone] will look at.
@export var target: Node2D

@export_range(-360, 360, 0.01, "radians_as_degrees") var additional_rotation: float = 0

@export_group("Constraints", "constraint_")

@export var constraint_enabled: bool = false:
	set(e):
		constraint_enabled = e
		queue_redraw()

@export var constraint_visible: bool = true:
	set(v):
		constraint_visible = v
		queue_redraw()

@export_range(-360, 360, 0.01, "radians_as_degrees") var constraint_min_angle: float = 0

@export_range(-360, 360, 0.01, "radians_as_degrees") var constraint_max_angle: float = TAU

@export var constraint_inverted: bool = false

@export var constraint_localspace: bool = true


func _draw() -> void:
	# The bone can be removed from tree and stored in a variable for later use.
	if not bone.is_inside_tree():
		return
	
	if constraint_visible:
		_draw_angle_constraints(
			bone, constraint_min_angle, constraint_max_angle,
			constraint_enabled, constraint_localspace, constraint_inverted
		)


func _start_listen_bone() -> void:
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
	if not bone.tree_exiting.is_connected(_forget_bone):
		bone.tree_exiting.connect(_forget_bone)
	
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
func _forget_bone() -> void:
	if bone.is_queued_for_deletion():
		bone = null


func _stop_listen_bone() -> void:
	if not bone:
		return
	
	if bone.child_order_changed.is_connected(queue_redraw):
		bone.child_order_changed.disconnect(queue_redraw)
	
	if bone.transform_changed.is_connected(queue_redraw):
		bone.transform_changed.disconnect(queue_redraw)
	
	if bone.tree_exiting.is_connected(queue_redraw):
		bone.tree_exiting.disconnect(queue_redraw)
	
	if bone.tree_exiting.is_connected(_forget_bone):
		bone.tree_exiting.disconnect(_forget_bone)
	
	if bone.child_bone_changing.is_connected(_listen_child_bone_changes):
		bone.child_bone_changing.disconnect(_listen_child_bone_changes)


func _undo_modifications() -> void:
	if bone:
		bone.restore_pose()


func _apply_modifications(_delta: float) -> void:
	if not enabled:
		return
	
	if not target or not target.is_inside_tree():
		return
	
	if not bone or not bone.is_inside_tree():
		return
	
	bone.cache_pose()
	bone.is_pose_modified = true
	
	# Get angle to target and remove any rotation given to the bone so it really points to the target.
	# In case you don't want it to point to the target, use additional_rotation.
	var angle_to_target: float = bone.get_angle_to(target.global_position)
	angle_to_target -= bone.get_bone_angle()
	angle_to_target += additional_rotation
	
	if constraint_enabled:
		var new_angle: float = angle_to_target
		
		if constraint_localspace:
			new_angle += bone.rotation
			new_angle = _clamp_angle(new_angle, constraint_min_angle, constraint_max_angle, constraint_inverted)
			bone.rotation = new_angle
		else:
			new_angle += bone.global_rotation
			new_angle = _clamp_angle(new_angle, constraint_min_angle, constraint_max_angle, constraint_inverted)
			bone.global_rotation = new_angle
	else:
		bone.rotate(angle_to_target)
