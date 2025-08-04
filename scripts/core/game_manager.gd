# game_manager.gd - AutoLoad Singleton with Croaker brand/model support
# Handles scene management, game state, and run persistence
extends Node

# Current scene reference
var current_scene: Node = null

# Run state
var current_croaker: Croaker = null
var ai_croakers: Array[Croaker] = []
var races_completed: int = 0
var last_race_position: int = 0
var current_series: int = 1  # Which series in the run (1-3)

# Available starter Croakers for new runs
var starter_pool: Array[Dictionary] = [
	{"brand": "toytoada", "model": "coroalla", "name": "Starter Frog"},
	{"brand": "croakswagen", "model": "beetle", "name": "Beginner Beetle"},
	{"brand": "leep", "model": "wrangler", "name": "Rookie Ranger"},
	{"brand": "forg", "model": "mustang", "name": "First Timer"}
]

func _ready() -> void:
	# Get the current scene (should be Main.tscn initially)
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	print("[GameManager] Initial scene loaded: ", current_scene.name)
	
	# Ensure Croaker data is loaded
	if Croaker.croaker_data.is_empty():
		Croaker._load_croaker_data()

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

# =============================
# RUN MANAGEMENT
# =============================

# Start a new run with a random starter Croaker
func start_new_run(player_name: String = "") -> void:
	print("[GameManager] Starting new run")
	
	# Reset run state
	races_completed = 0
	last_race_position = 0
	current_series = 1
	
	# Select random starter
	var starter = starter_pool[randi() % starter_pool.size()]
	
	# Create player's Croaker
	current_croaker = Croaker.create_from_brand(
		starter.brand,
		starter.model,
		player_name if player_name != "" else starter.name
	)
	
	# Generate AI opponents
	_generate_ai_opponents()
	
	print("[GameManager] New run started with %s %s" % [
		current_croaker.get_brand_name(),
		current_croaker.get_model_name()
	])

# Generate AI opponents for races
func _generate_ai_opponents() -> void:
	ai_croakers.clear()
	
	# For now, generate 3 random AI opponents
	# In full game, this would be based on current series/difficulty
	for i in range(3):
		var ai_croaker = Croaker.create_random()
		ai_croakers.append(ai_croaker)
		print("[GameManager] Generated AI opponent: %s (%s)" % [
			ai_croaker.name,
			ai_croaker.get_full_type_name()
		])

# Get the full race lineup (player + AI)
func get_race_lineup() -> Array[Croaker]:
	var lineup: Array[Croaker] = []
	
	# Player always in lane 1
	lineup.append(current_croaker)
	
	# Add AI opponents
	for ai in ai_croakers:
		lineup.append(ai)
	
	return lineup

# Apply an upgrade to the current Croaker
func apply_upgrade(stat_type: String, value: float) -> void:
	if not current_croaker:
		print("[GameManager] ERROR: No current Croaker to upgrade")
		return
	
	match stat_type:
		"jump_distance":
			current_croaker.jump_distance += value
			print("[GameManager] Jump distance upgraded: %.1f -> %.1f" % [
				current_croaker.jump_distance - value,
				current_croaker.jump_distance
			])
		"action_delay":
			current_croaker.action_delay += value
			current_croaker.action_delay = max(0.1, current_croaker.action_delay)  # Min delay
			print("[GameManager] Action delay upgraded: %.1f -> %.1f" % [
				current_croaker.action_delay - value,
				current_croaker.action_delay
			])
		"stamina":
			current_croaker.stamina += value
			print("[GameManager] Stamina upgraded: %.1f -> %.1f" % [
				current_croaker.stamina - value,
				current_croaker.stamina
			])

# Debug helper to print current Croaker stats
func debug_print_croaker_stats() -> void:
	if not current_croaker:
		print("[GameManager] No current Croaker")
		return
	
	print("[GameManager] Current Croaker Stats:")
	print("  Name: %s" % current_croaker.name)
	print("  Type: %s %s" % [
		current_croaker.get_brand_name(),
		current_croaker.get_model_name(),
	])
	print("  Jump Distance: %.1f" % current_croaker.jump_distance)
	print("  Action Delay: %.1f" % current_croaker.action_delay)
	print("  Stamina: %.1f" % current_croaker.stamina)
	print("  Personality: %s" % current_croaker.personality)

# Check if we're in an elimination race
func is_elimination_race() -> bool:
	return races_completed > 0 and races_completed % 3 == 0

# Get current race number in series (1-3)
func get_race_in_series() -> int:
	return (races_completed % 3) + 1

# Save/Load functionality (placeholder for MVP)
func save_run() -> void:
	print("[GameManager] Save run - NOT IMPLEMENTED FOR MVP")
	# TODO: Implement save system post-MVP

func load_run() -> bool:
	print("[GameManager] Load run - NOT IMPLEMENTED FOR MVP")
	# TODO: Implement load system post-MVP
	return false
