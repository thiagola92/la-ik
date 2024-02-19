@tool
class_name LaIKCCDIK
extends LaIK


@export var bone_root: LaBone:
	set(r):
		bone_root = r
		chain = []
		notify_property_list_changed()

@export var bone_tip: LaBone:
	set(t):
		bone_tip = t
		chain = []
		notify_property_list_changed()

@export var target: Node2D

## Contains all nodes in the chain, starting from the bone_tip and going to the bone_root.[br]
## It's easy to fill the array in this order and is the order which we calculate the IK.
var chain: Array[LaBone]:
	set(a):
		if not bone_root:
			chain = []
			return
		
		if not bone_tip:
			chain = []
			return
		
		# We will walk from the bone_tip until find bone_root.
		var current_bone: LaBone = bone_tip
		chain = []
		
		while(current_bone):
			chain.append(current_bone)
			
			# Finished with success because found the bone_root.
			if current_bone == bone_root:
				return
			
			current_bone = current_bone.get_parent()
			
			if not current_bone is LaBone:
				break
		
		# Didn't found bone_root, so clear the array.
		chain = []

var order: Array[int] = []


func _get(property: StringName) -> Variant:
	if property.begins_with("chain/"):
		var index = property.get_slice("/", 1).to_int()
		var what = property.get_slice("/", 2)
		
		match what:
			"bone":
				return chain[index]
	
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
			"hint_string": "-1, %s" % (chain.size() - 1)
		})
	
	return property_list


func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with("chain/"):
		var index = property.get_slice("/", 1).to_int()
		var what = property.get_slice("/", 2)
		
		match what:
			"bone":
				pass
	
	return false
