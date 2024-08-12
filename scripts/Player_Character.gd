extends CharacterBody3D

@onready var camera = $Camera3D
@onready var gun_particles = $Camera3D/Gun/Gunmesh/CPUParticles3D
@onready var death_particle_emitter = $DeathParticleEmitter
@onready var gun_audio_player = $Camera3D/Gun/GunAudioPlayer
@onready var health_regen_timer = $HealthRegenTimer
@onready var health_regen_tick = $HealthRegenTick
@onready var player_collision_shape = $CollisionShape3D
@onready var respawn_timer = $RespawnTimer
@onready var gun_anim_player = $Camera3D/Gun/GunAnimationPlayer
@onready var gunmesh = $Camera3D/Gun/Gunmesh
@onready var playermesh = $Playermesh

var current_recoil_velocity = Vector3.ZERO
var recoil_force = 5.0 # Adjust this value to get the desired recoil effect
var recoil_decay = 20.0 # How quickly the recoil force decays

#variables
var recieved_damage = 0
var move_speed = 10.0
var jump_vel = 10.0
var deadstatus = false
var taken_damage = false
var eDelta = 0
var gravity = 20.0
var can_shoot = true
var killer_id = "no-one"
var killcount = 0
var jumpcount = 1
@export var shooting_delay = 0.8
@export var default_damage : int = 50
@export var regenerated_health : int = 10
@export var health : int = 200

@export var playerragdollscene : PackedScene
@export var gunragdollscene : PackedScene

signal health_changed(health_value)
signal player_died
signal player_respawned
signal startgame

func _enter_tree():
	set_multiplayer_authority(name.to_int())
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = is_multiplayer_authority()

func _input(event):
	if is_multiplayer_authority():
		#Camera rotation
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * .005)
			camera.rotate_x(-event.relative.y * .005)
			camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	eDelta = delta
	if is_multiplayer_authority(): 
		if deadstatus == true: return
		
		apply_recoil(delta)
		
		#Shooting
		if Input.is_action_pressed("Mouse1"):
			if can_shoot:
				can_shoot = false
				shoot()
				await get_tree().create_timer(shooting_delay).timeout
				can_shoot = true
				emit_signal("startgame")
		#Movement and camera rotation
		if not is_on_floor():
			velocity.y -= gravity * delta
		if Input.is_action_just_pressed("space") and jumpcount > 0:
			velocity.y = jump_vel
			jumpcount -= 1
		if is_on_floor():
			jumpcount = 1
		var input_dir = Input.get_vector("pleft", "plright", "plup", "pldown")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
		velocity = velocity + current_recoil_velocity
		
		playeranimator.rpc(input_dir)
		
		move_and_slide()

@rpc("any_peer", "call_local") func playeranimator(input_dir):
	if gun_anim_player.current_animation == "shoot_gun":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		gun_anim_player.play("Walk_gun")
	else:
		gun_anim_player.play("Idle_gun")

func shoot():
	if !is_multiplayer_authority(): return
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_transform.basis.z * 100)

	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [self]
	
	var collision = space.intersect_ray(query)
	guneffects.rpc()
	gun_audio_player.play()
	
	#recoil stuff
	var shot_direction = camera.global_transform.basis.z.normalized()
	current_recoil_velocity = current_recoil_velocity + shot_direction * recoil_force
	
	if collision:
		var hit_object = collision.collider
		if hit_object.is_in_group("Damageable"):
			hit_object.set_killer.rpc_id(hit_object.get_multiplayer_authority(), name)
			hit_object.recieve_damage.rpc_id(hit_object.get_multiplayer_authority(), default_damage)

@rpc("any_peer", "call_local") func set_killer(killername):
	killer_id = killername

func apply_recoil(delta):
	 #Decay the recoil over time
	if current_recoil_velocity.length() > 0:
		current_recoil_velocity = current_recoil_velocity.lerp(Vector3.ZERO, recoil_decay * delta)

@rpc("unreliable", "call_local") func guneffects():
	gun_anim_player.stop()
	gun_anim_player.play("shoot_gun")
	gun_particles.restart()
	gun_particles.emitting = true
	
@rpc("any_peer") func recieve_damage(damage_amount):
	#print_debug(killer_id, " shot me owie for ", damage_amount, " damage")
	health = health - damage_amount
	if health > 200:
		health = 200
	if health < 0:
		health = 0
	health_changed.emit(health)
	taken_damage = true
	health_regen_tick.autostart = true
	health_regen_tick.start()
	health_regen_timer.start()

	if health <= 0 and !deadstatus:
		deadstatus = true
		deathfuncer.rpc()

func regenerate_health():
	health = health + regenerated_health
	health_changed.emit(health)

func picked_up_health():
	var healamount = -50
	recieve_damage(healamount)

@rpc("any_peer", "call_local") func deathfuncer():
	gunmesh.hide()
	playermesh.hide()
	
	var gunragdoll = gunragdollscene.instantiate()
	var playerragdoll = playerragdollscene.instantiate()
	print(self.position, " selfpos")
	print(playerragdoll.position, " ragodll")
	playerragdoll.position = playermesh.position
	gunragdoll.position = gunmesh.position
	add_child(gunragdoll)
	add_child(playerragdoll)
	
	death_particle_emitter.restart()
	death_particle_emitter.emitting = true
	health_regen_tick.autostart = false
	health_regen_tick.stop()
	health_regen_timer.stop()
	var player_id = str(self.name)
	player_died.emit(player_id)
	respawn_timer.start()
	
	await respawn_timer.timeout
	gunragdoll.queue_free()
	playerragdoll.queue_free()
	#remove_child(gunragdoll)
	#remove_child(playerragdoll)

@rpc("unreliable", "any_peer", "call_local") func updatePos(id, pos):
	if !is_multiplayer_authority():
		if name == id:
			position = lerp(position, pos, eDelta * 15)
@rpc("unreliable", "any_peer", "call_local") func updateRot(id, rot):
	if !is_multiplayer_authority():
		if name == id:
			rotation = lerp(rotation, rot, 1)
@rpc("unreliable", "any_peer", "call_local") func updateCamRot(id, camrot):
	if !is_multiplayer_authority():
		if name == id:
			camera.rotation = lerp(camera.rotation, camrot, 1)
#calls all the things that need to be synced between clients per tick
func _on_tick_timer_timeout():
	if is_multiplayer_authority():
		rpc("updatePos", name, position)
		rpc("updateRot", name, rotation)
		rpc("updateCamRot", name, camera.rotation)

func _on_health_regen_timer_timeout():
	taken_damage = false

func _on_health_regen_tick_timeout():
	if taken_damage == false:
		regenerate_health()

@rpc("call_local") func _on_respawn_timer_timeout():
	deadstatus = false
	gunmesh.show()
	playermesh.show()
	position = Vector3(1 * randi_range(-40,40), 4, 1 * randi_range(-40,40))
	player_respawned.emit()
	recieve_damage(-300000)
