extends CharacterBody2D

@export var roaming_speed = 50
@export var pursuing_speed = 150
@onready var LeftRay = $"Node2D/LeftRay"
@onready var RightRay = $"Node2D/RightRay"
@onready var target = $"../Player"
var alive = true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if LeftRay.is_colliding():
		#target = LeftRay.get_collider()
	#elif RightRay.is_colliding():
		#target = RightRay.get_collider()
	#if Input.is_key_pressed(KEY_V):
		#velocity.x = 0
		#$Label.visible = true
		#$Timer.start()
		#$AnimatedSprite2D.play("explode")
	if abs(position.x - target.position.x)<500 && abs(position.x - target.position.x)>=100 and alive and abs(position.y - target.position.y)<100:
		print("pursuing")
		var direction = 1 if position.x < target.position.x else -1
		velocity.x = pursuing_speed * direction
		$AnimatedSprite2D.play("pursue")
	elif alive :
		print("Nope")
		velocity.x = 0
	
	if abs(position.x - target.position.x)<100 and $Timer.is_stopped() and alive and abs(position.y - target.position.y)<100 :
		alive = false
		velocity.x = 0
		$Label.visible = true
		$Timer.start()
		$AnimatedSprite2D.play("explode")
		
	

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
func die():
	$Timer2.start()

func _on_timer_timeout() -> void:
	$Killzone.can_kill=true
	for i in $Killzone.get_overlapping_bodies():
		if i.has_method("die"):
			i.die()
	if $Timer2.is_stopped():
		$Timer2.start()

func _on_timer_2_timeout() -> void:
	queue_free()
