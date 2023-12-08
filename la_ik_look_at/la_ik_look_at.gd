@tool
class_name LaIKLookAt
extends LaIK


## The bone that will be looking to [member target].
@export var bone: LaBone:
	set(b):
		undo_modifications()
		queue_redraw()
		stop_listen_bone()
		bone = b
		start_listen_bone()

## The node which [member bone] will look at.
@export var target: Node2D

@export_range(-360, 360, 0.01, "radians_as_degrees") var additional_rotation: float = 0

@export_group("Constraints", "constraint_")

@export var constraint_enabled: bool = false:
	set(e):
		queue_redraw()
		constraint_enabled = e

@export var constraint_visible: bool = true:
	set(v):
		queue_redraw()
		constraint_visible = v

@export_range(-360, 360, 0.01, "radians_as_degrees") var constraint_min_angle: float = 0

@export_range(-360, 360, 0.01, "radians_as_degrees") var constraint_max_angle: float = TAU

@export var constraint_inverted: bool = false

@export var constraint_localspace: bool = true


func _draw() -> void:
	if constraint_visible:
		_draw_angle_constraints(
			bone, constraint_min_angle, constraint_max_angle,
			constraint_enabled, constraint_localspace, constraint_inverted
		)


func start_listen_bone() -> void:
	if bone:
		bone.transform_changed.connect(queue_redraw)


func stop_listen_bone() -> void:
	if bone:
		bone.transform_changed.disconnect(queue_redraw)


func undo_modifications() -> void:
	if bone:
		bone.restore_pose()


func apply_modifications(_delta: float) -> void:
	if not enabled:
		return
	
	if not target:
		return
	
	if not bone:
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
