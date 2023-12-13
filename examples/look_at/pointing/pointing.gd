extends Node2D


@export var skeleton: Node2D
@export var target: Marker2D
@export var ik: LaIKLookAt


func _process(_delta: float) -> void:
	target.global_position = get_global_mouse_position()


func _on_flip_button_pressed() -> void:
	scale.x = -scale.x


func _on_no_contraint_button_pressed() -> void:
	ik.constraint_enabled = false


func _on_no_pointing_behinds_pressed() -> void:
	ik.constraint_enabled = true
	ik.constraint_min_angle = PI/2
	ik.constraint_max_angle = -PI/2
	ik.constraint_inverted = true


func _on_move_button_pressed() -> void:
	var move_to = func(p: Vector2) -> Tween:
		var t: Tween = create_tween()
		t.tween_property(skeleton, "global_position", p, 1)
		return t
	
	await move_to.call(Vector2(300, 0)).finished
	await move_to.call(Vector2(300, 300)).finished
	await move_to.call(Vector2(-300, 300)).finished
	await move_to.call(Vector2(-300, -300)).finished
	await move_to.call(Vector2(300, -300)).finished
	await move_to.call(Vector2(300, 0)).finished
	await move_to.call(Vector2(0, 0)).finished
