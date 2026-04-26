extends TextureRect

var textures = [
	preload("res://sprite/fond/nuit_prairie/fond1.png"),
	preload("res://sprite/fond/nuit_prairie/fond2.png")
]
var flip = false;

func _on_timer_timeout() -> void:
	flip = not flip;
	if flip:
		texture = textures[1];
	else:
		texture = textures[0];
