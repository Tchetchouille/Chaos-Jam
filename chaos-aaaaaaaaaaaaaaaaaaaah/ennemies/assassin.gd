extends CharacterBody2D

@export var roaming_speed = 50
@export var pursuing_speed = 120
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
	if abs(position.x - target.position.x)<500 && abs(position.x - target.position.x)>=70 and abs(position.y - target.position.y)<100:
		print("pursuing")
		var direction = 1 if position.x < target.position.x else -1
		$AnimatedSprite2D.flip_h = true if direction<0 else false
		$Killzone/CollisionShape2D2.scale.x = -1 if direction<0 else 1
		velocity.x = pursuing_speed * direction
		#if not $AnimatedSprite2D.is_playing("sprint"):
		$AnimatedSprite2D.play("sprint")
		$Label.visible = false
		
	
	if abs(position.x - target.position.x)<70 and abs(position.y - target.position.y)<100:
		velocity.x = 0
		$AnimatedSprite2D.play("attack")
		$Label.visible = true
		$Killzone.can_kill=true
		if $Timer.is_stopped():
			$Timer.start()
	

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
func die():
	queue_free()


func _on_timer_timeout() -> void:
	$Killzone.can_kill=false
