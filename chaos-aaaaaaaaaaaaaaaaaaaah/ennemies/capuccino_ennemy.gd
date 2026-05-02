extends CharacterBody2D

@export var roaming_speed = 50
@export var pursuing_speed = 250
@onready var target = $"../Player"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(target.position)
	print(target.position.x-position.x)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	target = $"../Player"
	print(position.x)
	if abs(position.x - target.position.x)<300 && abs(position.x - target.position.x)>=100 :
		print("pursuing")
		velocity.x = pursuing_speed
	else :
		velocity.x = 0
	
	if abs(position.x - target.position.x)<100:
		velocity.x = 0
		$Timer.start()
		$AnimatedSprite2D.play("explode")
		
	

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func die():
	$Timer2.start()

func _on_timer_timeout() -> void:
	$Killzone.can_kill=true
	for i in $Killzone.get_overlapping_bodies():
		if i.has_method("die"):
			i.die()
	$Timer2.start()

func _on_timer_2_timeout() -> void:
	queue_free()
