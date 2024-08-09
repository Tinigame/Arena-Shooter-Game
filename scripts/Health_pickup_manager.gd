extends Node3D
@onready var timer = $Timer

@onready var healthpickuploaded = preload("res://scenes/health_pickup.tscn")

func _ready():
	spawnmedkit()

func spawnmedkit():
	var healthpickup = healthpickuploaded.instantiate()
	healthpickup.position.y = healthpickup.position.y + 1.4
	add_child(healthpickup)
	healthpickup.connect("PickedUp", medkiteated.bind(healthpickup))

func medkiteated(Medkit2):
	Medkit2.queue_free()
	timer.start()

func _on_timer_timeout():
	spawnmedkit()
