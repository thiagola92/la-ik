@tool
class_name LaIKCCD
extends LaIK


## First bone from the chain.
@export var root_bone: LaBone:
	set(r):
		_undo_modifications()
		_stop_listen_bones()
		root_bone = r
		
		# Call after loading saved chain from tscn file.
		_update_chain.call_deferred()
		_start_listen_bones.call_deferred()
		notify_property_list_changed.call_deferred()
		queue_redraw.call_deferred()

## Last bone from the chain.[br][br]
## [b]Note[/b]: It will not be affected by IK.
@export var tip_bone: LaBone:
	set(t):
		_undo_modifications()
		_stop_listen_bones()
		tip_bone = t
		
		# Call after loading saved chain from tscn file.
		_update_chain.call_deferred()
		_start_listen_bones.call_deferred()
		notify_property_list_changed.call_deferred()
		queue_redraw.call_deferred()

@export var target: Node2D

## Decide the order which bones from the chain will receive modifications.[br][br]
## The default behavior is going from [member tip_bone] to [member root_bone]
## (this is the order which parent bones are discovered).
## When true, it will go from [member root_bone] to [member tip_bone].
@export var forward_execution: bool:
	set(i):
		forward_execution = i
		chain.reverse()

# Contains data about all bones from root_bone until tip_bone (not including it).
var chain: Array[BoneData]


func _draw() -> void:
	for bone_data in chain:
		# The bone can be removed from tree and stored in a variable for later use.
		if not bone_data.bone.is_inside_tree():
			return
		
		if bone_data.constraint_visible:
			_draw_angle_constraints(
				bone_data.bone, bone_data.constraint_min_angle,
				bone_data.constraint_max_angle, bone_data.constraint_enabled,
				bone_data.constraint_localspace, bone_data.constraint_inverted
			)


func _get(property: StringName) -> Variant:
	if property.begins_with("chain/"):
		var parts: Array = property.split("/")
		var index: int = parts[1].to_int()
		var what: String = parts[2]
		
		if index >= chain.size() or index < 0:
			return null
		
		match what:
			"bone":
				return chain[index].bone
			"skip":
				return chain[index].skip
			"ignore_tip":
				return chain[index].ignore_tip
			"constraints" when parts[3] == "enabled":
				return chain[index].constraint_enabled
			"constraints" when parts[3] == "visible":
				return chain[index].constraint_visible
			"constraints" when parts[3] == "min_angle":
				return chain[index].constraint_min_angle
			"constraints" when parts[3] == "max_angle":
				return chain[index].constraint_max_angle
			"constraints" when parts[3] == "inverted":
				return chain[index].constraint_inverted
			"constraints" when parts[3] == "localspace":
				return chain[index].constraint_localspace
	
	return null


func _get_property_list() -> Array[Dictionary]:
	var property_list: Array[Dictionary] = []
	
	for i in chain.size():
		property_list.append({
			"name": "chain/%s/bone" % i,
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY,
			"hint": PROPERTY_HINT_NODE_TYPE,
			"hint_string": "LaBone"
		})
		
		property_list.append({
			"name": "chain/%s/skip" % i,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		
		property_list.append({
			"name": "chain/%s/ignore_tip" % i,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		
		property_list.append({
			"name": "chain/%s/constraints/enabled" % i,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		
		property_list.append({
			"name": "chain/%s/constraints/visible" % i,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		
		property_list.append({
			"name": "chain/%s/constraints/min_angle" % i,
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-360, 360, 0.01, radians_as_degrees"
		})
		
		property_list.append({
			"name": "chain/%s/constraints/max_angle" % i,
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-360, 360, 0.01, radians_as_degrees"
		})
		
		property_list.append({
			"name": "chain/%s/constraints/inverted" % i,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		
		property_list.append({
			"name": "chain/%s/constraints/localspace" % i,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	return property_list


func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with("chain/"):
		var parts: Array = property.split("/")
		var index: int = parts[1].to_int()
		var what: String = parts[2]
		
		# Make sure that a temporary BoneData exist so we can load settings from saves.
		if index >= chain.size():
			chain.resize(index + 1)
			
			# There is no guarantee that it will resize in order,
			# so we need to walk through all to make sure.
			for i in chain.size():
				if chain[i] == null:
					chain[i] = BoneData.new(null)
		
		match what:
			"bone":
				chain[index].bone = value
			"skip":
				chain[index].skip = value
			"ignore_tip":
				chain[index].ignore_tip = value
			"constraints" when parts[3] == "enabled":
				chain[index].constraint_enabled = value
			"constraints" when parts[3] == "visible":
				chain[index].constraint_visible = value
			"constraints" when parts[3] == "min_angle":
				chain[index].constraint_min_angle = value
			"constraints" when parts[3] == "max_angle":
				chain[index].constraint_max_angle = value
			"constraints" when parts[3] == "inverted":
				chain[index].constraint_inverted = value
			"constraints" when parts[3] == "localspace":
				chain[index].constraint_localspace = value
		
		# Restore pose before applying new modifications.
		_undo_modifications()
		queue_redraw()
		return true
	
	return false


# Update bone chain with all bones from tip_bone to root_bone (not including tip_bone).
# It will clear the chain if doesn't find a path.
# Note: It doesn't overwrite the chain if is the same (otherwise you lose the saved settings).
func _update_chain() -> void:
	if not root_bone:
		chain = []
		return
	
	if not tip_bone:
		chain = []
		return
	
	var parent = tip_bone.get_parent()
	var new_chain: Array[BoneData] = []
	
	while(parent):
		if not parent is LaBone:
			break
		
		new_chain.append(BoneData.new(parent))
		
		# Finished because found the root_bone.
		if parent == root_bone:
			if forward_execution:
				new_chain.reverse()
			
			# Checking if is a new chain [1].
			if new_chain.size() != chain.size():
				chain = new_chain
				return
			
			# Checking if is a new chain [2].
			for i in new_chain.size():
				if new_chain[i].bone != chain[i].bone:
					chain = new_chain
					return
			
			return
		
		parent = parent.get_parent()
	
	# Didn't found root_bone, so clear the array.
	chain = []


func _start_listen_bones() -> void:
	_start_listen_bone(tip_bone)
	
	for bone_data in chain:
		_start_listen_bone(bone_data.bone)


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
	if not bone.child_bone_changing.is_connected(_listen_child_bone_changes):
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
func _forget_bone(bone: LaBone) -> void:
	# False alarme, it's being stored for later usage.
	if not bone.is_queued_for_deletion():
		return
	
	_stop_listen_bone(bone)
	
	if bone == root_bone:
		root_bone = null
	elif bone == tip_bone:
		tip_bone = null
	
	_update_chain.call_deferred() # Call after bone leave the tree.


func _stop_listen_bones() -> void:
	_stop_listen_bone(tip_bone)
	
	for bone_data in chain:
		_stop_listen_bone(bone_data.bone)


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
	for bone_data in chain:
		if bone_data.bone:
			bone_data.bone.restore_pose()


func _apply_modifications(_delta: float) -> void:
	if not enabled:
		return
	
	if not target or not target.is_inside_tree():
		return
	
	if not tip_bone or not tip_bone.is_inside_tree():
		return
	
	# Changing one bone will emit a signal to update others bones autocalculated length/angle,
	# so we need to cache everyone before changing anyone.
	for bone_data in chain:
		# No need to check if each bone is inside tree or exist
		# because this would mean the same for the tip_bone.
		bone_data.bone.cache_pose()
		bone_data.bone.is_pose_modified = true
	
	for bone_data in chain:
		var bone: LaBone = bone_data.bone
		
		if bone_data.skip:
			continue
		
		if bone_data.ignore_tip:
			# Put bone close to target.
			bone.look_at(target.global_position)
			bone.rotation -= bone.bone_angle
		else:
			# Put bone close to target without pushing tip away.
			var angle_to_target: float = bone.global_position.angle_to_point(target.global_position)
			var angle_to_tip: float = bone.global_position.angle_to_point(tip_bone.global_position)
			var angle_diff: float = angle_to_target - angle_to_tip
			var same_sign: bool = bone.global_scale.sign().x == bone.global_scale.sign().y
			
			if same_sign:
				bone.rotate(angle_diff)
			else:
				bone.rotate(-angle_diff)
		
		# Not constraint, finished.
		if not bone_data.constraint_enabled:
			continue
		
		if bone_data.constraint_localspace:
			bone.rotation = _clamp_angle(
				bone.rotation,
				bone_data.constraint_min_angle,
				bone_data.constraint_max_angle,
				bone_data.constraint_inverted
			)
		else:
			bone.global_rotation = _clamp_angle(
				bone.global_rotation,
				bone_data.constraint_min_angle,
				bone_data.constraint_max_angle,
				bone_data.constraint_inverted
			)


# Data used in each bone during execution.
class BoneData extends RefCounted:
	var bone: LaBone
	var skip: bool = false
	var ignore_tip = false
	
	var constraint_enabled: bool = false
	var constraint_visible: bool = true
	var constraint_min_angle: float = 0
	var constraint_max_angle: float = TAU
	var constraint_inverted: bool = false
	var constraint_localspace: bool = true
	
	func _init(b: LaBone) -> void:
		bone = b
