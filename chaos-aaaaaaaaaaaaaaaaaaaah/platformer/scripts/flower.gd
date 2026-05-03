extends Area2D

@onready var game_manager = %game_manager



func _on_body_entered(body: Node2D) -> void:
	print("+1 flower")
	queue_free()
	
	game_manager.add_point()
	
