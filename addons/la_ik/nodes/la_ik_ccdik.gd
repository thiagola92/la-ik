@tool
class_name LaIKCCDIK
extends LaIK


## First bone from the chain.
@export var root_bone: LaBone:
	set(r):
		_stop_listen_bones()
		root_bone = r
		_update_chain()
		_start_listen_bones()
		notify_property_list_changed()
		queue_redraw()

## Last bone from the chain.[br][br]
## [b]Note[/b]: It will not be affected by IK.
@export var tip_bone: LaBone:
	set(t):
		_stop_listen_bones()
		tip_bone = t
		_update_chain()
		_start_listen_bones()
		notify_property_list_changed()
		queue_redraw()

@export var target: Node2D

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
			"order":
				return chain[index].order
			"skip":
				return chain[index].skip
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
			"name": "chain/%s/order" % i,
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0, %s" % (chain.size() - 1)
		})
		
		property_list.append({
			"name": "chain/%s/skip" % i,
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
		
		if index >= chain.size() or index < 0:
			return false
		
		match what:
			"bone":
				pass # Immutable
			"order":
				_set_chain_order(index, value)
			"skip":
				chain[index].skip = value
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
			_:
				return false
		queue_redraw()
		return true
	
	return false


# Set the BoneData.order, but this means you have to switch
# with the BoneData that had this order.
func _set_chain_order(index: int, order: int) -> void:
	var idx = -1
	
	for i in chain.size():
		if chain[i].order == order:
			idx = i
			break
	
	if idx == -1:
		return
	
	chain[idx].order = chain[index].order
	chain[index].order = order


func _update_chain() -> void:
	if not root_bone:
		chain = []
		return
	
	if not tip_bone:
		chain = []
		return
	
	# Starting from tip_bone but not including it.
	var parent = tip_bone.get_parent()
	var index = 0
	chain = []
	
	while(parent):
		if not parent is LaBone:
			break
		
		chain.append(BoneData.new(parent, index))
		
		# Finished with success because found the root_bone.
		if parent == root_bone:
			chain.reverse()
			return
		
		parent = parent.get_parent()
		index += 1
	
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
	
	# If bone is queue for deletion, set it to null.
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
	
	if bone == root_bone:
		root_bone = null
	else:
		_stop_listen_bones()
		_update_chain.call_deferred() # Call after bone leave the tree.
		_start_listen_bones.call_deferred()


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


# Data used in each bone during execution.
class BoneData:
	var bone: LaBone
	var order: int = 0
	var skip: bool = false
	
	var constraint_enabled: bool = false
	var constraint_visible: bool = true
	var constraint_min_angle: float = 0
	var constraint_max_angle: float = TAU
	var constraint_inverted: bool = false
	var constraint_localspace: bool = true
	
	func _init(b: LaBone, o: int) -> void:
		bone = b
		order = o
