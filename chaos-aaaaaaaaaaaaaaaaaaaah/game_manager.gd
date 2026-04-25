extends Node

@export var brainrot = ["assasin", "cappucin", "cocodril", "fraisit", "bananit", "strawberryn"]

func _ready():
	# Se connecte au signal émis à chaque changement de scène
	get_tree().connect("tree_changed", _on_scene_changed)

func _on_scene_changed():
	generate_text()

func generate_text():
	for node in get_all_children(get_tree().current_scene):
		if node is Label or node is RichTextLabel:
			var text_arr = node.text.split(" ")
			var text_length = len(text_arr)
			for i in range(round(text_length/3)):
				var rand_word_index = randi_range(0, len(brainrot)-1)
				var appendix = "a" if rand_word_index-text_length%2==0 else "o"
				text_arr[i] = brainrot[rand_word_index] + appendix
			var text_random = ""
			for i in text_arr:
				text_random += i + " "
			node.text = text_random.strip_edges()
			
			

func get_all_children(in_node, array := []):
	array.push_back(in_node)
	for child in in_node.get_children():
		array = get_all_children(child, array)
	return array
