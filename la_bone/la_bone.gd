@tool
@icon("res://icons/Bone2D.svg")
class_name LaBone
extends Node2D


signal transform_changed

## Show bone shapes.[br][br]
## Each bone can have multiple diamond shapes, this will show/hide every shape from this bone.
@export var show_bone: bool = true

## If [code]true[/code], it will attempt to use the first child bone to discover length and angle.[br][br]
## In case no child bone exist, [member bone_length] and [member bone_angle] will be used.
@export var autocalculate_length_and_angle: bool = true

@export_group("Length and Angle")

## [b]Note[/b]: Ignored in case [member autocalculate_length_and_angle] is [code]true[/code].
@export var bone_length: float = 16

## [b]Note[/b]: Ignored in case [member autocalculate_length_and_angle] is [code]true[/code].
@export_range(-360, 360, 0.1, "radians_as_degrees") var bone_angle: float = 0

var is_pose_modified: bool = false:
	set(m):
		is_pose_modified = m
		_calculate_length_and_angle()

var _pose_cache: Transform2D

var _calculated_bone_length: float = 16
var _calculated_bone_angle: float = 0

# Each bone can have multiple shapes, each shape points to a bone child.
# In case there is no bone child, a shape poiting to the right is generated.
var _bone_shapes: Array[Polygon2D] = []
var _bone_outline_shapes: Array[Polygon2D] = []


func _ready() -> void:
	_start_listen_child_bone()
	set_notify_transform(true)
	set_notify_local_transform(true)


func _process(_delta: float) -> void:
	cache_pose()
	_calculate_length_and_angle()
	_update_shapes()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			restore_pose()
		NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			transform_changed.emit()
		NOTIFICATION_CHILD_ORDER_CHANGED:
			_calculate_length_and_angle()
			_stop_listen_child_bone()
			_start_listen_child_bone()


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
	
	# Don't calculate with modified values.
	if is_pose_modified:
		return
	
	var child_bone = get_child_bone()
	
	if child_bone:
		# Using to_local() because CanvasItem.top_level could be checked.
		var child_local_pos: Vector2 = to_local(child_bone.global_position)
		_calculated_bone_length = child_local_pos.length()
		_calculated_bone_angle = child_local_pos.angle()
	else:
		_calculated_bone_length = bone_length
		_calculated_bone_angle = bone_angle


func _start_listen_child_bone() -> void:
	var child_bone: LaBone = get_child_bone()
	
	if not child_bone:
		return
	
	# If the first child bone move, we need to recalculate length and angle.
	if not child_bone.transform_changed.is_connected(_calculate_length_and_angle):
		child_bone.transform_changed.connect(_calculate_length_and_angle)


func _stop_listen_child_bone() -> void:
	var child_bone: LaBone = get_child_bone()
	
	if not child_bone:
		return
	
	if child_bone.transform_changed.is_connected(_calculate_length_and_angle):
		child_bone.transform_changed.disconnect(_calculate_length_and_angle)


func _update_shapes() -> void:
	_update_shapes_quantity()
	
	for i in _bone_shapes.size():
		_update_shape(_bone_shapes[i], _bone_outline_shapes[i], get_child_bone(i))
		_update_shape_color(_bone_shapes[i], _bone_outline_shapes[i])


func _update_shapes_quantity() -> void:
	var bones_quantity: int = 0
	
	# At the end you will have how many children are bones
	# and bones quantity will be more or equal to shapes quantity.
	for child in get_children():
		if child is LaBone:
			bones_quantity += 1
			
			if bones_quantity > _bone_shapes.size():
				_add_bone_shape()
	
	# In case you need to remove some shapes to match the bones_quantity.
	for i in (bones_quantity - _bone_shapes.size()):
		_remove_bone_shape()
	
	# You should never have no shapes.
	if _bone_shapes.size() == 0:
		_add_bone_shape()


func _add_bone_shape() -> void:
	var bone_shape: Polygon2D = Polygon2D.new()
	var bone_outline_shape: Polygon2D = Polygon2D.new()
	_bone_shapes.append(bone_shape)
	_bone_outline_shapes.append(bone_outline_shape)
	add_child(bone_shape)
	add_child(bone_outline_shape)


func _remove_bone_shape() -> void:
	if _bone_shapes.size() == 0:
		return
	
	(_bone_shapes.pop_back() as Polygon2D).queue_free()
	(_bone_outline_shapes.pop_back() as Polygon2D).queue_free()


func _update_shape(bone_shape: Polygon2D, bone_outline_shape: Polygon2D, child_bone: LaBone) -> void:
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
	if not EditorInterface.has_method("get_editor_settings"):
		return
	
	if not EditorInterface.has_method("get_selection"):
		return
	
	if not show_bone:
		return
	
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
