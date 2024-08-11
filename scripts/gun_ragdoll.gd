extends RigidBody3D


# Called when the node enters the scene tree for the first time.
func _ready():
	linear_velocity.x += 1
	angular_velocity.x += 1
	
func _physics_process(_delta):
	move_and_collide((linear_velocity) * _delta)
