extends Area2D

@onready var timer: Timer = $Timer
@export var can_kill = true
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die") and can_kill:
		body.die()
	# Brute force check de si le body c'est le player
	if body.has_method("change_mask"):
		get_the_player_killed()

func get_the_player_killed ():
	print("You died")
	Engine.time_scale = 0.7
	timer.start()

func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene() # Replace with function body.
