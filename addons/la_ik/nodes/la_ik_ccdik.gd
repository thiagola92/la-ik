@tool
class_name LaIKCCDIK
extends LaIK


## First bone from the chain.
@export var root_bone: LaBone:
	set(r):
		root_bone = r
		_update_chain()
		notify_property_list_changed()

## Last bone from the chain.[br][br]
## [b]Note[/b]: It will not be affected by IK.
@export var tip_bone: LaBone:
	set(t):
		tip_bone = t
		_update_chain()
		notify_property_list_changed()

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
