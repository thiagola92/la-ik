@tool
class_name LaIKFABR
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

## How many iterations do per execution.[br][br]
## More executions will make it converge to the final position faster.[br]
## This is capped at 10 to avoid to accidents of setting it too high.
@export_range(1, 10, 1) var iterations: int = 10

## Make [member tip_bone]'s parent use same rotation as the target.
@export var target_rotation: bool = false

# Contains data about all bones from root_bone until tip_bone (not including it).
# Ordered from tip_bone to root_bone, because this is the order which they are discovered.
var chain: Array[BoneData]


func _draw() -> void:
	for bone_data in chain:
		# The bone can be removed from tree and stored in a variable for later use.
		if not bone_data.bone.is_inside_tree():
			return


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
			"target_rotation":
				return chain[index].target_rotation
	
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
			"target_rotation":
				chain[index].target_rotation = value
		
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
	
	# Unfortunately we can't take advantage of for loops to check this.
	if not chain:
		return
	
	# Changing one bone will emit a signal to update others bones autocalculated length/angle,
	# so we need to cache everyone before changing anyone.
	for bone_data in chain:
		# No need to check if each bone is inside tree or exist
		# because this would mean the same for the tip_bone.
		bone_data.bone.cache_pose()
		bone_data.bone.is_pose_modified = true
	
	# Where root_bone started (the base of the arm).
	var base_global_position: Vector2 = root_bone.global_position
	
	for i in iterations:
		_apply_forwards_modifications()
		_apply_backwards_modifications(base_global_position)


# Move each bone forward to the target position.
func _apply_forwards_modifications() -> void:
	# The bone closest to the tip is aiming the target,
	# others bones are aiming the following bone.
	var target_global_position = target.global_position
	
	# Treating when the user wants the bone poiting same direction as the target.
	if target_rotation:
		var direction = Vector2(cos(target.global_rotation), sin(target.global_rotation))
		chain[0].bone.global_position = target_global_position - direction * chain[0].bone.get_bone_length()
	
	for bone_data in chain:
		var bone: LaBone = bone_data.bone
		
		# Look at target first.
		bone.look_at(target_global_position)
		
		# Avoid calculating ratio as INF.
		if target_global_position == bone.global_position:
			continue
		
		# Calculate new start position for the bone.
		var stretch: Vector2 = target_global_position - bone.global_position
		var ratio: float = bone.get_bone_length() / stretch.length()
		bone.global_position = target_global_position - stretch * ratio
		
		# Next bone target is this bone start position.
		target_global_position = bone.global_position


# Move each bone backward to the base position.
func _apply_backwards_modifications(base_global_position: Vector2) -> void:
	for i in range(chain.size() - 1, -1, -1):
		var bone_data: BoneData = chain[i]
		var bone: LaBone = bone_data.bone
		
		bone.global_position = base_global_position
		
		# Calculate next bone start position.
		var direction := Vector2(cos(bone.global_rotation), sin(bone.global_rotation))
		base_global_position = bone.global_position + direction * bone.get_bone_length()


# Data used in each bone during execution.
class BoneData extends RefCounted:
	var bone: LaBone
	var target_rotation: bool = false
	
	func _init(b: LaBone) -> void:
		bone = b
