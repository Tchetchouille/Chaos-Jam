extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -300.0

@export var fall_death_limit = 2000.0


func _physics_process(delta: float) -> void:

	if position.y > fall_death_limit:
		die()
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Handle down on platform
	if Input.is_action_pressed("ui_down"):
		velocity.y += 1

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction > 0:
		$AnimatedSprite2D.flip_h = true
	elif direction < 0 :
		$AnimatedSprite2D.flip_h = false
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	

func die():
	if $Timer.is_stopped():
		print("You died")
		Engine.time_scale = 0.7
		$Timer.start()

func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	print("You died for real this time")
	get_tree().change_scene_to_file("res://Shopifina/Shop.tscn")
