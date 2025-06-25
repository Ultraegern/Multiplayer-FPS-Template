extends CharacterBody3D
class_name Player

const GUN_SHOT: AudioStream = preload("res://audio/645317__darkshroom__m9_noisegate-1780.ogg")
const GUN_HIT: AudioStream = preload("res://assets/audio/hitmarker_2.mp3")

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $Camera3D/Node3D/M4Carbine/AnimationPlayer2
@onready var muzzle_flash: GPUParticles3D = $Camera3D/pistol/GPUParticles3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var gun_audio_player: AudioStreamPlayer3D = %GunshotSound
@onready var world: GameMagager = $".."
@onready var player_username: LineEdit = $"../Menu/MainMenu/MarginContainer/VBoxContainer/PlayerInfoHBoxContainer/PlayerUsername"
@onready var gun_animation_tree: AnimationTree = $Camera3D/GunAnimationTree

const MAX_HEALTH: int = 100
var health: int = MAX_HEALTH

## The xyz position of the random spawns, you can add as many as you want!
@export var spawns: PackedVector3Array = ([
	Vector3(-18, 0.2, 0),
	Vector3(18, 0.2, 0),
	Vector3(-2.8, 0.2, -6),
	Vector3(-17,0,17),
	Vector3(17,0,17),
	Vector3(17,0,-17),
	Vector3(-17,0,-17)
])
var sensitivity : float =  .005
var controller_sensitivity : float =  .010

var axis_vector : Vector2
var	mouse_captured : bool = true

const SPEED = 5.5
const JUMP_VELOCITY = 5.5

func _enter_tree() -> void:
	set_multiplayer_authority(int(str(name)))

func _ready() -> void:
	if not is_multiplayer_authority(): return
	
	var username: String = player_username.text if player_username.text else ("Player: " + str(name))
	world.call_register_player({"username":username}, int(str(name)))
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	position = spawns[randi() % spawns.size()]

func _process(_delta: float) -> void:
	sensitivity = Global.sensitivity
	controller_sensitivity = Global.controller_sensitivity
	
	rotate_y(-axis_vector.x * controller_sensitivity)
	camera.rotate_x(-axis_vector.y * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	axis_vector = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_pressed("shoot"):
		gun_animation_tree.parameters.conditions.shoot = true
	else:
		gun_animation_tree.parameters.conditions.shoot = false
	
	if Input.is_action_just_pressed("respawn"):
		recieve_damage(10000)
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func shoot() -> void:
	rpc("play_shoot_effects")
	if raycast.is_colliding() and str(raycast.get_collider()).contains("CharacterBody3D") :
		var hit_player: Object = raycast.get_collider()
		hit_player.recieve_damage.rpc_id(hit_player.get_multiplayer_authority())
		gun_audio_player.stream = GUN_HIT
		gun_audio_player.play()
	else:
		gun_audio_player.stream = GUN_SHOT
		gun_audio_player.play()

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null:
		if not is_multiplayer_authority(): return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	if anim_player.current_animation == "Shoot":
		pass
	elif Input.is_action_pressed("shoot") and not anim_player.current_animation == "shoot":
		pass
	elif not input_dir == Vector2.ZERO and is_on_floor() :
		anim_player.play("Move")
	else:
		anim_player.play("Idle")
	
	move_and_slide()

@rpc("authority", "call_local", "unreliable")
func play_shoot_effects() -> void:
	anim_player.stop()
	anim_player.play("Shoot Hip")
	#muzzle_flash.restart()
	#muzzle_flash.emitting = true

@rpc("any_peer", "call_remote", "unreliable")
func recieve_damage(damage: int = 1) -> void:
	health -= damage
	if health <= 0:
		health = MAX_HEALTH
		position = spawns[randi() % spawns.size()]

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Shoot Hip" and not Input.is_action_pressed("shoot"):
		anim_player.play("Idle")
	elif anim_name == "Shoot Hip" and Input.is_action_pressed("shoot"):
		shoot()
