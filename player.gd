extends CharacterBody3D

#Player Nodes

@onready var neck = $neck
@onready var head = $neck/head
@onready var camera_3d = $neck/head/eyes/Camera3D
@onready var standing_collision = $standing_collision
@onready var crouching_collision = $crouching_collision
@onready var ray_cast_3d = $RayCast3D
@onready var eyes = $neck/head/eyes

#speed variables

@export var walk_speed = 5.0
var current_speed = 0.0
var sprint_speed = walk_speed * 2
var crouch_speed = walk_speed * 0.6
var slide_speed = sprint_speed + 1


#movement variables

const jump_velocity = 4.5
var crouch_depth = -0.7
var lerp_speed = 10.0
var air_lerp_speed = 3.0
var free_look_tilt = 8

#states
var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

#slide vars

var slide_timer = 0.0
var slide_timer_max = 1.1
var slide_vector = Vector2.ZERO

#headbobbing vars
const head_bob_sprint_speed = 25.0
const head_bob_walk_speed = 14.0
const head_bob_crouch_speed = 10.0

var head_bob_sprint_intensity = 0.2
var head_bob_walk_intensity = 0.1
var head_bob_crouch_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

#input variables

const mouse_sens = 0.4
var direction = Vector3.ZERO

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


#Mouse Look

func _input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			neck.rotation.y  = clamp(neck.rotation.y, deg_to_rad(-90), deg_to_rad(90))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
			head.rotation.x  = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(60))


#Movement
func _physics_process(delta):
	
	#get movement
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	if Input.is_action_pressed("crouch") || sliding:
		#Crouching
		if is_on_floor():
			current_speed = lerp(current_speed, crouch_speed, delta * lerp_speed)
		
		head.position.y = lerp(head.position.y,crouch_depth, delta * lerp_speed)
		
		standing_collision.disabled = true
		crouching_collision.disabled = false
		
		#Slide begin
		if sprinting && input_dir != Vector2.ZERO && is_on_floor():
			sliding=true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			free_looking = true
		
		walking = false
		sprinting = false
		crouching = true
		
	elif !ray_cast_3d.is_colliding():
		
		#Standing
		standing_collision.disabled = false
		crouching_collision.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		
		if Input.is_action_pressed("sprint"):
			current_speed = lerp(current_speed, sprint_speed, delta * lerp_speed)
			walking = false
			sprinting = true
			crouching = false
			
		else:
			current_speed = lerp(current_speed, walk_speed, delta * lerp_speed)
			walking = true
			sprinting = false
			crouching = false

	#Freelooking
	if Input.is_action_pressed("free look") || sliding:
		free_looking = true
		
		if sliding:
			camera_3d.rotation.z = lerp(camera_3d.rotation.z,-deg_to_rad(7.0),delta * lerp_speed)
		else:
			camera_3d.rotation.z = -deg_to_rad(neck.rotation.y * free_look_tilt)
		
	else:
		free_looking = false
		neck.rotation.y = lerp (neck.rotation.y, 0.0, delta * lerp_speed)
		camera_3d.rotation.z = lerp (camera_3d.rotation.z, 0.0, delta * lerp_speed)
	
	#handle sliding
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
	
	#handle head bobbing
	if sprinting:
		head_bobbing_current_intensity = head_bob_sprint_intensity
		head_bobbing_index += head_bob_sprint_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bob_walk_intensity
		head_bobbing_index += head_bob_walk_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bob_crouch_intensity
		head_bobbing_index += head_bob_crouch_speed * delta
		
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index / 2) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_current_intensity, delta * lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)
			# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta



	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


	# Get the input direction and handle the movement/deceleration.
	if is_on_floor():
		direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta * lerp_speed)
	else:
		direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta * air_lerp_speed)
		
	
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0 ,slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.1) * slide_speed
		
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		#handle respawn
		if position.y <= -15:
			transform.origin = Vector3(0,0,0)


	move_and_slide()
