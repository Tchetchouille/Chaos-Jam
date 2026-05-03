extends Node

var _generator := BrainrotNameGenerator.new()
var _top_k: int = 12
var _temperature: float = 0.75
var _max_length: int = 16


func _ready() -> void:
	_generator.load_model("res://rotmaxxer/microgpt_weights.json")
	if _generator.is_loaded():
		print("BrainrotGenerator: model loaded")
	else:
		print("BrainrotGenerator: no model loaded :(")


func generate_name() -> String:
	if not _generator.is_loaded():
		return "brainrot"
	return _generator.generate_noun(_max_length, _temperature, _top_k)
