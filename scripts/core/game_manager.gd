# game_manager.gd - AutoLoad Singleton
# Handles scene management, global game state, and Croaker persistence
extends Node

# Current scene reference
var current_scene: Node = null

# Game State - Persists between scenes
var current_croaker: Croaker = null
var ai_croakers: Array[Croaker] = []  # Store AI opponents for consistency

func _ready() -> void:
	# Get the current scene (should be Main.tscn initially)
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	print("[GameManager] Initial scene loaded: ", current_scene.name)

# Initialize a new run with a fresh Croaker
func start_new_run(croaker_name: String = "Player Frog") -> void:
	print("[GameManager] Starting new run with Croaker: '%s'" % croaker_name)
	
	# Create player's Croaker with base stats
	current_croaker = Croaker.new(croaker_name)
	current_croaker.jump_distance = 5.0
	current_croaker.action_delay = 1.0
	current_croaker.stamina = 100.0
	
	# Generate AI opponents (can be reused across races in the same run)
	_generate_ai_croakers()
	
	print("[GameManager] Player Croaker created - Jump: %.1f, Delay: %.1f" % [
		current_croaker.jump_distance, 
		current_croaker.action_delay
	])

# Generate AI opponents for the run
func _generate_ai_croakers() -> void:
	ai_croakers.clear()
	
	# AI templates with different strategies
	var ai_templates = [
		{"name": "Speedy", "jump": 4.5, "delay": 0.85},
		{"name": "Jumpy", "jump": 6.0, "delay": 1.15},
		{"name": "Steady", "jump": 5.0, "delay": 1.0}
	]
	
	for template in ai_templates:
		var ai = Croaker.new(template.name)
		ai.jump_distance = template.jump
		ai.action_delay = template.delay
		ai_croakers.append(ai)
		
		print("[GameManager] AI Croaker created: %s - Jump: %.1f, Delay: %.1f" % [
			ai.name, ai.jump_distance, ai.action_delay
		])

# Apply an upgrade to the current Croaker
func apply_upgrade(upgrade_type: String, value: float) -> void:
	if not current_croaker:
		print("[GameManager] ERROR: No current Croaker to upgrade")
		return
	
	match upgrade_type:
		"jump_distance":
			current_croaker.jump_distance += value
			print("[GameManager] Applied jump upgrade: +%.1f (new total: %.1f)" % [
				value, current_croaker.jump_distance
			])
		"action_delay":
			current_croaker.action_delay += value  # Negative values make it faster
			current_croaker.action_delay = max(0.1, current_croaker.action_delay)  # Min cap
			print("[GameManager] Applied speed upgrade: %.1f (new delay: %.1f)" % [
				value, current_croaker.action_delay
			])
		"stamina":
			current_croaker.stamina += value
			print("[GameManager] Applied stamina upgrade: +%.1f (new total: %.1f)" % [
				value, current_croaker.stamina
			])
		_:
			print("[GameManager] Unknown upgrade type: ", upgrade_type)

# Get all racers for a race (player + AI)
func get_race_lineup() -> Array[Croaker]:
	var lineup: Array[Croaker] = []
	
	if current_croaker:
		lineup.append(current_croaker)
	
	lineup.append_array(ai_croakers)
	
	print("[GameManager] Race lineup prepared: %d racers" % lineup.size())
	return lineup

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

# Debug function to print current Croaker stats
func debug_print_croaker_stats() -> void:
	if current_croaker:
		print("[GameManager] Current Croaker Stats:")
		print("  Name: %s" % current_croaker.name)
		print("  Jump Distance: %.1f" % current_croaker.jump_distance)
		print("  Action Delay: %.1f" % current_croaker.action_delay)
		print("  Stamina: %.1f" % current_croaker.stamina)
		print("  Upgrades: %d" % current_croaker.upgrades_equipped.size())
		print("  Warts: %d" % current_croaker.warts_equipped.size())
	else:
		print("[GameManager] No current Croaker")
