extends Node
class_name GameMagager

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

@export_multiline var help_str: String

enum {ENet, WebSocket, WebRTC}
enum {NoUPnP, UPnP}
const PLAYER = preload("res://player.tscn")
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var websocket_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
#var webrtc_peer: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var paused: bool = false
var options: bool = false
var controller: bool = false
var upnp_thread: Thread = null
var is_server: bool = false
var player_info: Dictionary[int, Dictionary] = {} #Dictionary[int, Dictionary[String, String]]

func _enter_tree() -> void:
	ProjectSettings.set_setting("display/window/stretch/scale", float(DisplayServer.window_get_size().y))

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print(help_str)
		print()
		print("Starting dedicated server...")
		_on_host_button_pressed(true)
	elif not OS.get_cmdline_args().find("--host") == -1:
		_on_host_button_pressed(false)
		AudioServer.set_bus_mute(0, true)

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause") and not main_menu.visible and not options_menu.visible:
		paused = not paused
	if event is InputEventJoypadMotion:
		controller = true
	elif event is InputEventMouseMotion:
		controller = false
	#if event.is_action_pressed("ui_accept"): rpc("_print")

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
	if not controller:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options = true

func _on_back_pressed() -> void:
	if options:
		$Menu/Blur.hide()
		if not controller:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		options = false

func _on_host_button_pressed(is_dedicated_server: bool = false) -> void:
	is_server = true
	var host_port: int = int(host_port_box.value) if (not is_dedicated_server or (OS.get_cmdline_args().find("-p") == -1 and OS.get_cmdline_args().find("--port") == -1)) else int(OS.get_cmdline_args()[(OS.get_cmdline_args().find("-p") + 1) if (not OS.get_cmdline_args().find("-p") == -1) else (OS.get_cmdline_args().find("--port") + 1)])
	if not is_dedicated_server:
		main_menu.hide()
		$Menu/DollyCamera.hide()
		$Menu/Blur.hide()
		menu_music.stop()
		server_cam.current = true
	
	if (network_backend_host_option_button.selected == ENet and not is_dedicated_server) \
	 or (not((not OS.get_cmdline_args().find("--websocket") == -1) or (not OS.get_cmdline_args().find("--webrtc") == -1)) and is_dedicated_server):
		enet_peer.create_server(host_port)
		multiplayer.multiplayer_peer = enet_peer
		multiplayer.peer_connected.connect(
			func(new_peer_id: int) -> void:
				add_player(new_peer_id)
				rpc_id(new_peer_id, "register_previously_added_players", player_info)
				)
		multiplayer.peer_disconnected.connect(remove_player)
		print("Started ENet server on port " + str(host_port))
		
	elif (network_backend_host_option_button.selected == WebSocket and not is_dedicated_server) \
	 or ((not OS.get_cmdline_args().find("--websocket") == -1) and is_dedicated_server):
		websocket_peer.create_server(host_port)
		multiplayer.multiplayer_peer = websocket_peer
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_connected.connect(
			func(new_peer_id: int) -> void:
				add_player(new_peer_id)
				rpc_id(new_peer_id, "register_previously_added_players", player_info)
				)
		multiplayer.peer_disconnected.connect(remove_player)
		print("Started WebSocket server on port " + str(host_port))
		
	#elif (network_backend_host_option_button.selected == WebRTC and not is_dedicated_server) \
	# or (not OS.get_cmdline_args().find("--webrtc") == -1 and is_dedicated_server): TODO
	#	webrtc_peer.create_server(host_port)
	#	multiplayer.multiplayer_peer = webrtc_peer
	#	multiplayer.peer_connected.connect(
	#		func(new_peer_id: int) -> void:
	#			add_player(new_peer_id)
	#			rpc_id(new_peer_id, "register_previously_added_players", player_info)
	#			)
	#	multiplayer.peer_disconnected.connect(remove_player)
	#	print("Started WebRTC server on port " + str(host_port))
	
	player_info[1] = {"username":"Server"}
	
	if (upnp_option_button.selected == UPnP and not is_dedicated_server) or (not OS.get_cmdline_args().find("upnp") == -1 and is_dedicated_server): upnp_setup_threaded(int(host_port_box.value))

func _on_join_button_pressed() -> void:
	main_menu.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	
	var address: String = address_entry.text if address_entry.text else "127.0.0.1"
	
	if network_backend_join_option_button.selected == ENet:
		var error: Error = enet_peer.create_client(address, int(join_port_box.value))
		if not error == OK:
			push_error(error)
		if options_menu.visible:
			options_menu.hide()
		multiplayer.multiplayer_peer = enet_peer
		
	elif network_backend_join_option_button.selected == WebSocket:
		var error: Error = websocket_peer.create_client("ws://" + address + ":" + str(int(join_port_box.value)))
		if not error == OK:
			push_error(error)
		if options_menu.visible:
			options_menu.hide()
		multiplayer.multiplayer_peer = websocket_peer
		
	#elif network_backend_join_option_button.selected == WebRTC: TODO
	#	webrtc_peer.create_client("ws://" + address + ":" + str(int(join_port_box.value)))
	#	if options_menu.visible:
	#		options_menu.hide()
	#	multiplayer.multiplayer_peer = webrtc_peer

func _on_options_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		options_menu.show()
	else:
		options_menu.hide()

func _on_music_toggle_toggled(toggled_on: bool) -> void:
	menu_music.stream_paused = not toggled_on

func add_player(peer_id: int) -> void:
	var player: Player = PLAYER.instantiate()
	player.name = str(peer_id)
	add_child(player)
	print("Player " + str(peer_id) + " joined")

func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
	print("Player " + str(peer_id) + " left")

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

func _on_disable_camera_toggle_toggled(_toggled_on: bool) -> void:
	# RenderingServer.viewport_set_disable_3d(, toggled_on) #TODO
	pass

@rpc("authority", "call_remote", "reliable")
func register_previously_added_players(previous_player_info: Dictionary[int, Dictionary]) -> void:
	for key: int in previous_player_info.keys():
		register_player(previous_player_info[key], key)

func call_register_player(new_player_info: Dictionary, new_player_id: int) -> void:
	rpc("register_newly_added_player", new_player_info, new_player_id)
	register_player(new_player_info, new_player_id)

@rpc("any_peer", "call_remote", "reliable")
func register_newly_added_player(new_player_info: Dictionary, new_player_id: int) -> void:
	register_player(new_player_info, new_player_id)

func register_player(new_player_info: Dictionary, new_player_id: int) -> void: #Dictionary[int, Dictionary[String, String]]
	player_info[new_player_id] = new_player_info
	update_nametags()

func update_nametags() -> void:
	for child in get_children():
		if child is Player:
			var id: int = int(child.name)
			var label: Label3D = child.find_child("Label3D")
			if label and player_info.has(id): label.text = player_info[id]["username"]

enum {windowed, windowedFullscreen, fullscreen, exclusiveFullscreen}
func _on_fullscreen_item_selected(index: int) -> void:
	match index:
		windowed:
			DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_WINDOWED)
			#DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		#windowedFullscreen:
			#DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_WINDOWED)
			#DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			#DisplayServer.window_set_size()
		#fullscreen:
			#DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN)
			#DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		exclusiveFullscreen:
			DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			#DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

enum {off, fxaa, taa, msaa_x2, msaa_x4, msaa_x8}
func _on_aa_item_selected(index: int) -> void:
	var rid: RID = get_tree().get_root().get_viewport_rid()
	match index:
		off:
			RenderingServer.viewport_set_msaa_3d(rid, RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.viewport_set_screen_space_aa(rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.viewport_set_use_taa(rid, false)
		fxaa:
			RenderingServer.viewport_set_msaa_3d(rid, RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.viewport_set_screen_space_aa(rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.viewport_set_use_taa(rid, false)
		taa:
			RenderingServer.viewport_set_msaa_3d(rid, RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.viewport_set_screen_space_aa(rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.viewport_set_use_taa(rid, true)
		msaa_x2:
			RenderingServer.viewport_set_msaa_3d(rid, RenderingServer.VIEWPORT_MSAA_2X)
			RenderingServer.viewport_set_screen_space_aa(rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.viewport_set_use_taa(rid, false)
		msaa_x4:
			RenderingServer.viewport_set_msaa_3d(rid, RenderingServer.VIEWPORT_MSAA_4X)
			RenderingServer.viewport_set_screen_space_aa(rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.viewport_set_use_taa(rid, false)
		msaa_x8:
			RenderingServer.viewport_set_msaa_3d(rid, RenderingServer.VIEWPORT_MSAA_8X)
			RenderingServer.viewport_set_screen_space_aa(rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.viewport_set_use_taa(rid, false)
