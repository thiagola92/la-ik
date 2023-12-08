@tool
@icon("res://icons/Bone2D.svg")
class_name LaBone
extends Node2D


signal transform_changed

## If [code]true[/code], it will use the first child bone to discover length and angle.
@export var autocalculate_length_and_angle: bool = true

@export_group("Autocalculate OFF")
@export var bone_length: float = 16
@export_range(-360, 360, 0.1, "radians_as_degrees") var bone_angle: float = 0

@export_group("Editor Settings")
@export var show_bone_shape: bool = true:
	set(v):
		show_bone_shape = v
		_bone_shape.visible = v
		_bone_outline_shape.visible = v

var is_pose_modified: bool = false
var _pose_cache: Transform2D

var _calculated_bone_length: float = 16
var _calculated_bone_angle: float = 0

var _bone_shape: Polygon2D
var _bone_outline_shape: Polygon2D


func _ready() -> void:
	_create_bone_shape()
	set_notify_transform(true)
	set_notify_local_transform(true)


func _process(_delta: float) -> void:
	_calculate_length_and_rotation()
	for child in get_children():
		if child is LaBone:
			_update_bone_shape(child)
	_update_bone_color()
	_refresh_cache()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			restore_pose()
		NOTIFICATION_TRANSFORM_CHANGED:
			transform_changed.emit()


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


func _create_bone_shape() -> void:
	_bone_shape = Polygon2D.new()
	_bone_outline_shape = Polygon2D.new()
	add_child(_bone_shape)
	add_child(_bone_outline_shape)


func _calculate_length_and_rotation() -> void:
	if not autocalculate_length_and_angle:
		return
	
	# Don't calculate with modified values.
	if is_pose_modified:
		return
	
	var child_bone = _get_first_bone_child()
	
	if not child_bone:
		return
	
	# Using to_local() because CanvasItem.top_level chould be checked.
	var child_local_pos = to_local(child_bone.global_position)
	_calculated_bone_length = child_local_pos.length()
	_calculated_bone_angle = child_local_pos.angle()


func _get_first_bone_child() -> LaBone:
	for child in get_children():
		if child is LaBone:
			return child
	return null


func _update_bone_color() -> void:
	if not EditorInterface.has_method("get_editor_settings"):
		return
	
	if not EditorInterface.has_method("get_selection"):
		return
	
	if not show_bone_shape:
		return
	
	var editor_settings = EditorInterface.get_editor_settings()
	var bone_ik_color: Color = editor_settings.get_setting("editors/2d/bone_ik_color")
	var bone_color1: Color = editor_settings.get_setting("editors/2d/bone_color1")
	var bone_color2: Color = editor_settings.get_setting("editors/2d/bone_color2")
	
	if is_pose_modified:
		_bone_shape.vertex_colors = [
			bone_ik_color,
			bone_ik_color,
			bone_ik_color,
			bone_ik_color,
		]
	else:
		_bone_shape.vertex_colors = [
			bone_color1,
			bone_color2,
			bone_color1,
			bone_color2,
		]
	
	var editor_selection = EditorInterface.get_selection()
	var bone_outline_color: Color = editor_settings.get_setting("editors/2d/bone_outline_color")
	var bone_selected_color: Color = editor_settings.get_setting("editors/2d/bone_selected_color")
	
	if self in editor_selection.get_selected_nodes():
		_bone_outline_shape.vertex_colors = [
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
			bone_selected_color,
		]
	else:
		_bone_outline_shape.vertex_colors = [
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
			bone_outline_color,
		]


func _update_bone_shape(child_bone: LaBone = null) -> void:
	if not EditorInterface.has_method("get_editor_settings"):
		return
	
	if not show_bone_shape:
		return
	
	var settings = EditorInterface.get_editor_settings()
	var bone_width: float = settings.get_setting("editors/2d/bone_width")
	var bone_outline_width: float = settings.get_setting("editors/2d/bone_outline_size")
	var angle: float = get_bone_angle()
	var length: float = get_bone_length()
	var bone_direction: Vector2
	
	if child_bone:
		bone_direction = child_bone.global_position - global_position
	else:
		bone_direction = Vector2(cos(angle), sin(angle)) * length
	
	var bone_normal = bone_direction.rotated(PI/2).normalized() * bone_width
	
	_bone_shape.polygon = [
		Vector2(0, 0),
		bone_direction * 0.2 + bone_normal,
		bone_direction,
		bone_direction * 0.2 - bone_normal,
	]
	
	var bone_direction_n = bone_direction.normalized()
	var bone_normal_n = bone_normal.normalized()
	
	_bone_outline_shape.polygon = [
		(-bone_direction_n - bone_normal_n) * bone_outline_width,
		(-bone_direction_n + bone_normal_n) * bone_outline_width,
		(bone_direction * 0.2 + bone_normal) + bone_normal_n * bone_outline_width,
		bone_direction + (bone_direction_n + bone_normal_n) * bone_outline_width,
		bone_direction + (bone_direction_n - bone_normal_n) * bone_outline_width,
		(bone_direction * 0.2 - bone_normal) - bone_normal_n * bone_outline_width,
	]


func _refresh_cache() -> void:
	if is_pose_modified:
		return
	
	_pose_cache = transform
