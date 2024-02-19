@tool
class_name LaIKCCDIK
extends LaIK


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


func _get(property: StringName) -> Variant:
	if property.begins_with("chain/"):
		var index = property.get_slice("/", 1).to_int()
		var what = property.get_slice("/", 2)
		
		if index >= chain.size() or index < 0:
			return null
		
		match what:
			"bone":
				return chain[index].bone
			"order":
				return chain[index].order
			"skip":
				return chain[index].skip
	
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
	
	return property_list


func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with("chain/"):
		var index = property.get_slice("/", 1).to_int()
		var what = property.get_slice("/", 2)
		
		if index >= chain.size() or index < 0:
			return false
		
		match what:
			"bone":
				return false
			"order":
				_set_chain_order(index, value)
				return true
			"skip":
				chain[index].skip = value
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
	var order: int
	var skip: bool
	
	func _init(b: LaBone, o: int) -> void:
		bone = b
		order = o
