extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var gui = $CanvasLayer/GUI
@onready var health_bar = $CanvasLayer/GUI/HealthBar
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AdressEntry
@onready var players = $Players
@onready var dead_text = $CanvasLayer/GUI/CenterContainer/DeadText
@onready var flicker_timer = $CanvasLayer/GUI/CenterContainer/DeadText/FlickerTimer
@onready var leaderboard_v = $CanvasLayer/GUI/Leaderboard/LeaderboardV
@onready var funnymap = $Funnymap

@export var player_spawner : PackedScene
@export var player_scene : PackedScene

var player_spawner_node
var Leaderboard = {}
var port = 25566
var peer = ENetMultiplayerPeer.new()

func _ready():
	gui.hide()

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	#adds the first local player
	add_player()
	main_menu.hide()
	gui.show()

func _on_join_button_pressed():
	peer.create_client(address_entry.text, port)
	multiplayer.multiplayer_peer = peer
	main_menu.hide()
	gui.show()

func add_player(id = 1):
	
	player_spawner_node = player_spawner.instantiate()
	player_spawner_node.name = str(id, " player spawner")
	player_spawner_node.playerIDset(id)
	var spawnloc = randi_range(10, 20)
	player_spawner_node.position = Vector3(0, 10, spawnloc)
	funnymap.add_child(player_spawner_node)
	
	var player = player_scene.instantiate()
	player.name = str(id) 
	player.position = player_spawner_node.position
	players.add_child(player)
	if player.is_multiplayer_authority():
		player.player_died.connect(kill_player)
		player.health_changed.connect(update_health_bar)
	print("player added with id: ", id)
	Leaderboard[str(id)] = 0 

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		node.player_died.connect(kill_player)
		node.player_respawned.connect(respawn_player)

func update_health_bar(health_value):
	clampi(health_value, 0, 200)
	health_bar.value = health_value

@rpc("any_peer", "call_local") func kill_player(id):
	dead_text.show()
	var playerkill = players.get_node(id).killer_id
	#update_leaderboard.rpc(playerkill)
	print(playerkill, " killed you hahaha")

#its like commit test
#big stroke
#LEADERBOARD AAAAAAAJJJJHHHH
#@rpc("any_peer", "call_local") func update_leaderboard(killername):
	#print(Leaderboard)
	#for playe in Leaderboard:
		#var pLabel = Label.new()
		#leaderboard_v.add_child(pLabel)
		#pLabel.text = str("Player ", str(Leaderboard[playe]), ": ", Leaderboard[playe])
	#Leaderboard[killername] += 1

@rpc("any_peer", "call_local") func respawn_player(id):
	
	dead_text.hide()
	players.get_node(id).position = player_spawner_node.position

@rpc("any_peer", "call_local") func del_player(id):
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
