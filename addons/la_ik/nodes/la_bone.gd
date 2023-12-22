@tool
@icon("../icons/LaBone.svg")
class_name LaBone
extends Node2D


signal transform_changed

signal child_bone_changing(previous: LaBone, current: LaBone)

## Show bone shapes.[br][br]
## Each bone can have multiple diamond shapes, this will show/hide every shape from this bone.
@export var show_bone: bool = true:
	set(s):
		show_bone = s
		_update_shapes()

## If [code]true[/code], it will attempt to use the first child bone to discover length and angle.[br][br]
## In case no child bone exist, [member bone_length] and [member bone_angle] will be used.
@export var autocalculate_length_and_angle: bool = true:
	set(a):
		autocalculate_length_and_angle = a
		_update_shapes()

@export_group("Length and Angle")

## [b]Note[/b]: Ignored in case [member autocalculate_length_and_angle] is [code]true[/code].
@export var bone_length: float = 16:
	set(l):
		bone_length = l
		_update_shapes()

## [b]Note[/b]: Ignored in case [member autocalculate_length_and_angle] is [code]true[/code].
@export_range(-360, 360, 0.1, "radians_as_degrees") var bone_angle: float = 0:
	set(a):
		bone_angle = a
		_update_shapes()

var is_pose_modified: bool = false:
	set(m):
		is_pose_modified = m
		_calculate_length_and_angle()

# Default value is important because gives you a cache at scene start.
var _pose_cache: Transform2D = transform

# The fist child bone is used to calculate length and angle,
# so we need to notify IK nodes that it change, so they can recalculate values.
var _child_bone: LaBone:
	set(b):
		if b != _child_bone:
			child_bone_changing.emit(_child_bone, b)
			_child_bone = b

var _calculated_bone_length: float = 16
var _calculated_bone_angle: float = 0

# Each bone can have multiple shapes, each shape points to a bone child.
var _bone_shapes: Array[Polygon2D] = []
var _bone_outline_shapes: Array[Polygon2D] = []

# This shape appears when autocalculate_length_and_angle is false or there is no child bone.
var _bone_shape: Polygon2D
var _bone_outline_shape: Polygon2D


func _ready() -> void:
	set_notify_transform(true)
	set_notify_local_transform(true)
	
	_bone_shape = _create_bone_shape()
	_bone_outline_shape = _create_bone_outline_shape()
	
	add_child(_bone_shape)
	add_child(_bone_outline_shape)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			restore_pose()
		NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			cache_pose()
			_calculate_length_and_angle()
			_update_shapes()
			transform_changed.emit()
		NOTIFICATION_CHILD_ORDER_CHANGED:
			_child_bone = get_child_bone()
			_start_listen_child_bones()
			_calculate_length_and_angle()
			_update_shapes()


func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "_calculated_bone_length",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_NONE,
	}, {
		"name": "_calculated_bone_angle",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_NONE,
	}]


func get_bone_angle() -> float:
	if autocalculate_length_and_angle:
		return _calculated_bone_angle
	return bone_angle


func get_bone_length() -> float:
	if autocalculate_length_and_angle:
		return _calculated_bone_length
	return bone_length


func cache_pose() -> void:
	# Do not cache a modified pose.
	if is_pose_modified:
		return
	
	_pose_cache = transform


func restore_pose() -> void:
	transform = _pose_cache
	is_pose_modified = false


## Get the (n-1)º bone child or return null if doesn't found.
## Similar to array where first position is 0.
func get_child_bone(n: int = 0) -> LaBone:
	for child in get_children():
		if child is LaBone:
			n -= 1
		
		if n < 0:
			return child
	
	return null


func _calculate_length_and_angle() -> void:
	if not autocalculate_length_and_angle:
		return
	
	# Calculating while modifying can cause unexpected behaviors.
	if is_pose_modified:
		return
	
	if _child_bone:
		# This will take scale in count, which is good because you get the right length
		# even when only one axis is scaled.
		_calculated_bone_length = (_child_bone.global_position - global_position).length()
		
		# This will NOT take scale in count, which is good because you get the right angle
		# even when scaling X by a negative number.
		_calculated_bone_angle = to_local(_child_bone.global_position).angle()
	else:
		_calculated_bone_length = bone_length
		_calculated_bone_angle = bone_angle


func _start_listen_child_bones() -> void:
	for child_bone in get_children():
		if child_bone is LaBone:
			_start_listen_child_bone(child_bone)


func _start_listen_child_bone(child_bone: LaBone) -> void:
	if not child_bone:
		return
	
	# If the first child bone move, we need to recalculate length and angle.
	if not child_bone.transform_changed.is_connected(_calculate_length_and_angle):
		child_bone.transform_changed.connect(_calculate_length_and_angle)
	
	# If the first child bone move, we need to redraw shapes.
	if not child_bone.transform_changed.is_connected(_update_shapes):
		child_bone.transform_changed.connect(_update_shapes)


func _stop_listen_child_bone(child_bone: LaBone) -> void:
	if not child_bone:
		return
	
	if child_bone.transform_changed.is_connected(_calculate_length_and_angle):
		child_bone.transform_changed.disconnect(_calculate_length_and_angle)
	
	if child_bone.transform_changed.is_connected(_update_shapes):
		child_bone.transform_changed.disconnect(_update_shapes)


func _update_shapes() -> void:
	if not _bone_shape:
		return
	
	if not _bone_outline_shape:
		return
	
	_update_shapes_quantity()
	
	for i in _bone_shapes.size():
		# Before this node free itself, it needs to free it children.
		# So there is a chance that the child doesn't exist anymore and
		# the array is holding a <Freed Object>.
		if not is_instance_valid(_bone_shapes[i]):
			return
		
		if not is_instance_valid(_bone_outline_shapes[i]):
			return
		
		_update_shape(_bone_shapes[i], _bone_outline_shapes[i], get_child_bone(i))
		_update_shape_color(_bone_shapes[i], _bone_outline_shapes[i])
	
	_bone_shape.visible = not autocalculate_length_and_angle or _bone_shapes.size() == 0
	_bone_outline_shape.visible = not autocalculate_length_and_angle or _bone_shapes.size() == 0
	
	_update_shape(_bone_shape, _bone_outline_shape, null)
	_update_shape_color(_bone_shape, _bone_outline_shape)


func _update_shapes_quantity() -> void:
	var bones_quantity: int = 0
	
	# At the end you will have how many children are bones
	# and bones quantity will be more or equal to shapes quantity.
	for child in get_children():
		if child is LaBone:
			bones_quantity += 1
			
			if bones_quantity > _bone_shapes.size():
				_increase_bone_shapes()
	
	# In case you need to remove some shapes to match the bones_quantity.
	for i in (bones_quantity - _bone_shapes.size()):
		_decrease_bone_shapes()


func _increase_bone_shapes() -> void:
	var bone_shape: Polygon2D = _create_bone_shape()
	var bone_outline_shape: Polygon2D = _create_bone_outline_shape()
	_bone_shapes.append(bone_shape)
	_bone_outline_shapes.append(bone_outline_shape)
	add_child(bone_shape)
	add_child(bone_outline_shape)


func _create_bone_shape() -> Polygon2D:
	var bone_shape: Polygon2D = Polygon2D.new()
	bone_shape.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	return bone_shape


func _create_bone_outline_shape() -> Polygon2D:
	var bone_outline_shape: Polygon2D = Polygon2D.new()
	bone_outline_shape.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	return bone_outline_shape


func _decrease_bone_shapes() -> void:
	if _bone_shapes.size() == 0:
		return
	
	(_bone_shapes.pop_back() as Polygon2D).queue_free()
	(_bone_outline_shapes.pop_back() as Polygon2D).queue_free()


func _update_shape(bone_shape: Polygon2D, bone_outline_shape: Polygon2D, child_bone: LaBone) -> void:
	if not bone_shape:
		return
	
	if not bone_outline_shape:
		return
	
	if not EditorInterface.has_method("get_editor_settings"):
		return
	
	if not show_bone:
		bone_shape.polygon = []
		bone_outline_shape.polygon = []
		return
	
	var settings = EditorInterface.get_editor_settings()
	var bone_width: float = settings.get_setting("editors/2d/bone_width")
	var bone_outline_width: float = settings.get_setting("editors/2d/bone_outline_size")
	var bone_direction: Vector2
	
	if not child_bone:
		var angle: float = get_bone_angle()
		var length: float = get_bone_length()
		bone_direction = Vector2(cos(angle), sin(angle)) * length
	else:
		# Use to_local() to not take the scale in count.
		# Scale will be applied automatically when the polygon is added as child.
		bone_direction = to_local(child_bone.global_position)
	
	var bone_normal = bone_direction.rotated(PI/2).normalized() * bone_width
	
	bone_shape.polygon = [
		Vector2(0, 0),
		bone_direction * 0.2 + bone_normal,
		bone_direction,
		bone_direction * 0.2 - bone_normal,
	]
	
	var bone_direction_n = bone_direction.normalized()
	var bone_normal_n = bone_normal.normalized()
	
	bone_outline_shape.polygon = [
		(-bone_direction_n - bone_normal_n) * bone_outline_width,
		(-bone_direction_n + bone_normal_n) * bone_outline_width,
		(bone_direction * 0.2 + bone_normal) + bone_normal_n * bone_outline_width,
		bone_direction + (bone_direction_n + bone_normal_n) * bone_outline_width,
		bone_direction + (bone_direction_n - bone_normal_n) * bone_outline_width,
		(bone_direction * 0.2 - bone_normal) - bone_normal_n * bone_outline_width,
	]


func _update_shape_color(bone_shape: Polygon2D, bone_outline_shape: Polygon2D) -> void:
	if not bone_shape:
		return
	
	if not bone_outline_shape:
		return
	
	if not EditorInterface.has_method("get_editor_settings"):
		return
	
	if not EditorInterface.has_method("get_selection"):
		return
	
	if not show_bone:
		return
	
	bone_shape.self_modulate = self_modulate
	bone_outline_shape.self_modulate = self_modulate
	
	var editor_settings = EditorInterface.get_editor_settings()
	var bone_ik_color: Color = editor_settings.get_setting("editors/2d/bone_ik_color")
	var bone_color1: Color = editor_settings.get_setting("editors/2d/bone_color1")
	var bone_color2: Color = editor_settings.get_setting("editors/2d/bone_color2")
	
	if is_pose_modified:
		bone_shape.vertex_colors = [
			bone_ik_color,
			bone_ik_color,
			bone_ik_color,
			bone_ik_color,
		]
	else:
		bone_shape.vertex_colors = [
			bone_color1,
			bone_color2,
			bone_color1,
			bone_color2,
		]
	
	var editor_selection = EditorInterface.get_selection()
	var bone_outline_color: Color = editor_settings.get_setting("editors/2d/bone_outline_color")
	var bone_selected_color: Color = editor_settings.get_setting("editors/2d/bone_selected_color")
	
	if self in editor_selection.get_selected_nodes():
		bone_outline_shape.vertex_colors = [
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
		]
	else:
		bone_outline_shape.vertex_colors = [
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
		]
