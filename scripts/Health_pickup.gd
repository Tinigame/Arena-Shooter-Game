extends Area3D

@onready var collision = $CollisionShape3D

var rotate_direction = Vector3(0, 1, 0)
signal PickedUp

func _ready():
	self.add_to_group("Pickup")

func _physics_process(_delta):
	self.rotate(rotate_direction.normalized(), 0.05)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		emit_signal("PickedUp")
		body.picked_up_health()
