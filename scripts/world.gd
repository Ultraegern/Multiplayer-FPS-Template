extends Node

@onready var main_menu: PanelContainer = $Menu/MainMenu
@onready var options_menu: PanelContainer = $Menu/Options
@onready var pause_menu: PanelContainer = $Menu/PauseMenu
@onready var address_entry: LineEdit = %AddressEntry
@onready var menu_music: AudioStreamPlayer = %MenuMusic
@onready var port_box: SpinBox = $Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/PortBox
@onready var option_button: OptionButton = $Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/OptionButton

const Player = preload("res://player.tscn")
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var paused: bool = false
var options: bool = false
var controller: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause") and !main_menu.visible and !options_menu.visible:
		paused = not paused
	if event is InputEventJoypadMotion:
		controller = true
	elif event is InputEventMouseMotion:
		controller = false

func _process(_delta: float) -> void:
	if paused:
		$Menu/Blur.show()
		pause_menu.show()
		if !controller:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume_pressed() -> void:
	if !options:
		$Menu/Blur.hide()
	$Menu/PauseMenu.hide()
	if !controller:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused = false
	
func _on_options_pressed() -> void:
	_on_resume_pressed()
	$Menu/Options.show()
	$Menu/Blur.show()
	%Fullscreen.grab_focus()
	if !controller:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options = true

func _on_back_pressed() -> void:
	if options:
		$Menu/Blur.hide()
		if !controller:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		options = false

#func _ready() -> void:
func _on_host_button_pressed() -> void:
	main_menu.hide()
	$Menu/DollyCamera.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	
	enet_peer.create_server(int(port_box.value))
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	if options_menu.visible:
		options_menu.hide()
	
	add_player(multiplayer.get_unique_id())
	
	if option_button.selected == 1: upnp_setup()

func _on_join_button_pressed() -> void:
	main_menu.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	
	enet_peer.create_client(address_entry.text, int(port_box.value))
	if options_menu.visible:
		options_menu.hide()
	multiplayer.multiplayer_peer = enet_peer

func _on_options_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		options_menu.show()
	else:
		options_menu.hide()
		
func _on_music_toggle_toggled(toggled_on: bool) -> void:
	menu_music.stream_paused = not toggled_on

func add_player(peer_id: int) -> void:
	var player: Node = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)

func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func upnp_setup() -> void:
	var upnp: UPNP = UPNP.new()
	
	upnp.discover() #TODO run asyncronus
	upnp.add_port_mapping(int(port_box.value))
	
	var ip: String = upnp.query_external_address()
	if ip == "":
		print("Failed to establish upnp connection!")
	else:
		print("Success! Join Address: %s" % upnp.query_external_address())

func _on_advanced_toggle_toggled(toggled_on: bool) -> void:
	$Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/PortBox.visible = toggled_on
	$Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/OptionButton.visible = toggled_on
