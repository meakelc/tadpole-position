# game_manager.gd - AutoLoad Singleton
# Handles scene management and global game state
extends Node

# Current scene reference
var current_scene: Node = null

func _ready() -> void:
	# Get the current scene (should be Main.tscn initially)
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	print("[GameManager] Initial scene loaded: ", current_scene.name)

# Change to a new scene
func change_scene(path: String) -> void:
	var current_name = "null"
	if current_scene:
		current_name = current_scene.name
	print("[GameManager] Changing scene from '%s' to '%s'" % [current_name, path])
	
	# Validate the path exists
	if not ResourceLoader.exists(path):
		print("[GameManager] ERROR: Scene path does not exist: ", path)
		return
	
	# Call deferred to avoid errors during scene processing
	call_deferred("_deferred_change_scene", path)

# Deferred scene change to avoid timing issues
func _deferred_change_scene(path: String) -> void:
	# Free the current scene
	if current_scene:
		current_scene.queue_free()
	
	# Load the new scene
	var new_scene_resource = ResourceLoader.load(path)
	if not new_scene_resource:
		print("[GameManager] ERROR: Failed to load scene resource: ", path)
		return
	
	# Instance the new scene
	var new_scene = new_scene_resource.instantiate()
	if not new_scene:
		print("[GameManager] ERROR: Failed to instantiate scene: ", path)
		return
	
	# Add it to the scene tree
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene = new_scene
	
	print("[GameManager] Scene change completed: ", current_scene.name)

# Utility function to get current scene name
func get_current_scene_name() -> String:
	if current_scene:
		return current_scene.name
	else:
		return "none"
