extends RigidBody3D


# Called when the node enters the scene tree for the first time.
func _ready():
	linear_velocity + Vector3(5, 0, 0)

func _physics_process(delta):
	pass
