extends Node

signal upnp_completed(error: int)

@onready var main_menu: PanelContainer = $Menu/MainMenu
@onready var options_menu: PanelContainer = $Menu/Options
@onready var pause_menu: PanelContainer = $Menu/PauseMenu
@onready var menu_music: AudioStreamPlayer = %MenuMusic

@onready var address_entry: LineEdit = %AddressEntry
@onready var join_port_box: SpinBox = $Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/JoinPortBox
@onready var network_backend_join_option_button: OptionButton = $Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/NetworkBackendJoinOptionButton

@onready var host_port_box: SpinBox = $Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/HostPortBox
@onready var upnp_option_button: OptionButton = $Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/UPnPOptionButton
@onready var network_backend_host_option_button: OptionButton = $Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/NetworkBackendHostOptionButton

@onready var server_cam: Camera3D = $ServerCamPivot/ServerCam
@onready var server_cam_pivot: Node3D = $ServerCamPivot

enum {ENet, WebSocket}
const Player = preload("res://player.tscn")
#var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var websocket_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
var paused: bool = false
var options: bool = false
var controller: bool = false
var upnp_thread: Thread = null
var is_server: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause") and not main_menu.visible and not options_menu.visible:
		paused = not paused
	if event is InputEventJoypadMotion:
		controller = true
	elif event is InputEventMouseMotion:
		controller = false

func _process(delta: float) -> void:
	if is_server: server_cam_pivot.rotate_y(deg_to_rad(5.625) * delta)
	if paused:
		$Menu/Blur.show()
		pause_menu.show()
		if not controller:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume_pressed() -> void:
	if not options:
		$Menu/Blur.hide()
	$Menu/PauseMenu.hide()
	if not controller:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused = false
	
func _on_options_pressed() -> void:
	_on_resume_pressed()
	$Menu/Options.show()
	$Menu/Blur.show()
	%Fullscreen.grab_focus()
	if not controller:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options = true

func _on_back_pressed() -> void:
	if options:
		$Menu/Blur.hide()
		if not controller:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		options = false

#func _ready() -> void:
func _on_host_button_pressed() -> void:
	is_server = true
	main_menu.hide()
	$Menu/DollyCamera.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	server_cam.current = true
	
	if network_backend_host_option_button.selected == ENet:
		#enet_peer.create_server(int(host_port_box.value))
		#multiplayer.multiplayer_peer = enet_peer
		#multiplayer.peer_connected.connect(add_player)
		#multiplayer.peer_disconnected.connect(remove_player)
		pass
	elif network_backend_host_option_button.selected == WebSocket:
		multiplayer.multiplayer_peer = null
		websocket_peer.create_server(int(host_port_box.value))
		multiplayer.multiplayer_peer = websocket_peer
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(remove_player)
	
	#if options_menu.visible:
	#	options_menu.hide()
	#
	#add_player(multiplayer.get_unique_id())
	
	if upnp_option_button.selected == 1: upnp_setup_threaded(int(host_port_box.value))

func _on_join_button_pressed() -> void:
	main_menu.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	
	var address: String = address_entry.text if address_entry.text else "127.0.0.1"
	
	if network_backend_join_option_button.selected == ENet:
		#enet_peer.create_client(address, int(join_port_box.value))
		#if options_menu.visible:
		#	options_menu.hide()
		#multiplayer.multiplayer_peer = enet_peer
		pass
	elif network_backend_join_option_button.selected == WebSocket:
		multiplayer.multiplayer_peer = null
		websocket_peer.create_client("ws://" + address + ":" + str(int(join_port_box.value)))
		if options_menu.visible:
			options_menu.hide()
		multiplayer.multiplayer_peer = websocket_peer

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

func upnp_setup_threaded(port: int) -> void:
	upnp_thread = Thread.new()
	upnp_thread.start(_upnp_setup.bind(port))

func _upnp_setup(port: int) -> void:
	var upnp: UPNP = UPNP.new()
	
	var err: int = upnp.discover()
	if not err == OK:
		push_error("UPnP error nr: " + str(err))
		upnp_completed.emit(err)
		return
	
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name"), "UDP")
		upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name"), "TCP")
		upnp_completed.emit(OK)
	
	var ip: String = upnp.query_external_address()
	if ip == "":
		print("Failed to establish upnp connection!")
	else:
		print("Success! Join Address: %s" % ip)
		DisplayServer.clipboard_set(ip)

func _on_advanced_toggle_toggled(toggled_on: bool) -> void:
	join_port_box.visible = toggled_on
	network_backend_join_option_button.visible = toggled_on
	$Menu/MainMenu/MarginContainer/VBoxContainer/HSeparator.visible = toggled_on
	$Menu/MainMenu/MarginContainer/VBoxContainer/HostButton.visible = toggled_on
	$Menu/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2.visible = toggled_on

func _exit_tree() -> void:
	# Wait for thread finish here to handle game exit while the thread is running.
	if upnp_thread: upnp_thread.wait_to_finish()
