extends TextureRect

var textures = [
	preload("res://assets/fond/jour_prairie/fond_jour_1.png"),
	preload("res://assets/fond/jour_prairie/fond_jour_2.png")
]
var flip = false;

func _on_timer_timeout() -> void:
	flip = not flip;
	if flip:
		texture = textures[1];
	else:
		texture = textures[0];
