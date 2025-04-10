extends Camera2D
@onready var soft_body_2d = $"../SoftBody2D"
@onready var bone_13 = $"../SoftBody2D/Bone-13"

func _process(_delta):
	position = bone_13.position
