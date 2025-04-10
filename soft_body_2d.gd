extends SoftBody2D

const POWER = 8000

func _physics_process(delta):
	var horizontal_force = delta * (-POWER * (int)(Input.is_action_pressed("ui_left")) + POWER * (int)(Input.is_action_pressed("ui_right")))
	var vertical_force = delta * (-POWER * 2.0 * (int)(Input.is_action_pressed("ui_up")) + POWER * (int)(Input.is_action_pressed("ui_down")))
	
	apply_force(Vector2(horizontal_force, vertical_force))
