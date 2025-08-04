# game_manager.gd - AutoLoad Singleton
# Handles scene management, global game state, and Croaker persistence
extends Node

# Current scene reference
var current_scene: Node = null

# Game State - Persists between scenes
var current_croaker: Croaker = null
var ai_croakers: Array[Croaker] = []  # Store AI opponents for consistency

# Race Results - New properties for storing complete race results
var last_race_results: Array = []  # All racers in finishing order
var last_race_position: int = 0  # Player's finishing position (for backward compatibility)
var races_completed: int = 0  # Track total races in current run

# Croaker Data - Loaded from JSON
var croaker_data: Dictionary = {}

func _ready() -> void:
	# Get the current scene (should be Main.tscn initially)
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	print("[GameManager] Initial scene loaded: ", current_scene.name)
	
	# Load croaker data from JSON
	_load_croaker_data()

# Load croaker configuration from JSON file
func _load_croaker_data() -> void:
	var file_path = "res://data/croakers.json"
	
	if not FileAccess.file_exists(file_path):
		print("[GameManager] ERROR: croakers.json not found at ", file_path)
		_fallback_croaker_data()
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[GameManager] ERROR: Could not open croakers.json")
		_fallback_croaker_data()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("[GameManager] ERROR: Failed to parse croakers.json")
		_fallback_croaker_data()
		return
	
	croaker_data = json.data
	print("[GameManager] Successfully loaded croaker data with %d brands" % croaker_data.brands.size())

# Fallback croaker data if JSON loading fails
func _fallback_croaker_data() -> void:
	print("[GameManager] Using fallback croaker data")
	croaker_data = {
		"brands": {
			"forg": {
				"display_name": "Forg",
				"models": {
					"mustang": {
						"display_name": "Mustang GT",
						"base_stats": {
							"jump_distance": 7.0,
							"action_delay": 1.3,
							"stamina": 90.0
						},
						"color_primary": "#1E3A8A",
						"color_secondary": "#FFFFFF",
						"size_modifier": 1.2,
						"personality_pool": ["aggressive", "powerful", "loud"]
					}
				}
			}
		},
		"stat_variance": {
			"jump_distance": 0.5,
			"action_delay": 0.1,
			"stamina": 10.0
		}
	}

# Create a Croaker from brand and model data
func create_croaker_from_data(croaker_name: String, brand_id: String, model_id: String) -> Croaker:
	if not croaker_data.has("brands") or not croaker_data.brands.has(brand_id):
		print("[GameManager] ERROR: Brand '%s' not found in croaker data" % brand_id)
		return null
	
	var brand_data = croaker_data.brands[brand_id]
	if not brand_data.has("models") or not brand_data.models.has(model_id):
		print("[GameManager] ERROR: Model '%s' not found in brand '%s'" % [model_id, brand_id])
		return null
	
	var model_data = brand_data.models[model_id]
	var base_stats = model_data.base_stats
	
	# Create the Croaker
	var croaker = Croaker.new(croaker_name)
	
	# Apply base stats with variance
	var variance = croaker_data.get("stat_variance", {})
	croaker.jump_distance = _apply_stat_variance(base_stats.jump_distance, variance.get("jump_distance", 0.0))
	croaker.action_delay = _apply_stat_variance(base_stats.action_delay, variance.get("action_delay", 0.0))
	croaker.stamina = _apply_stat_variance(base_stats.stamina, variance.get("stamina", 0.0))
	
	# Set brand and model info
	croaker.brand_id = brand_id
	croaker.model_id = model_id
	croaker.brand_name = brand_data.display_name
	croaker.model_name = model_data.display_name
	
	# Set visual properties
	croaker.color_primary = Color(model_data.get("color_primary", "#FFFFFF"))
	croaker.color_secondary = Color(model_data.get("color_secondary", "#000000"))
	croaker.size_modifier = model_data.get("size_modifier", 1.0)
	
	# Set personality
	var personality_pool = model_data.get("personality_pool", ["steady"])
	croaker.personality = personality_pool[randi() % personality_pool.size()]
	
	print("[GameManager] Created Croaker: %s (%s %s) - Jump: %.1f, Delay: %.1f, Personality: %s" % [
		croaker.name,
		croaker.brand_name,
		croaker.model_name,
		croaker.jump_distance,
		croaker.action_delay,
		croaker.personality
	])
	
	return croaker

# Apply stat variance to a base value
func _apply_stat_variance(base_value: float, variance: float) -> float:
	if variance <= 0.0:
		return base_value
	
	var min_val = base_value - variance
	var max_val = base_value + variance
	return randf_range(min_val, max_val)

# Get a random brand and model combination
func get_random_brand_model() -> Dictionary:
	if not croaker_data.has("brands") or croaker_data.brands.is_empty():
		print("[GameManager] ERROR: No brands available in croaker data")
		return {"brand_id": "", "model_id": ""}
	
	var brand_keys = croaker_data.brands.keys()
	var random_brand_id = brand_keys[randi() % brand_keys.size()]
	var brand_data = croaker_data.brands[random_brand_id]
	
	if not brand_data.has("models") or brand_data.models.is_empty():
		print("[GameManager] ERROR: No models available for brand '%s'" % random_brand_id)
		return {"brand_id": "", "model_id": ""}
	
	var model_keys = brand_data.models.keys()
	var random_model_id = model_keys[randi() % model_keys.size()]
	
	return {
		"brand_id": random_brand_id,
		"model_id": random_model_id
	}

# Initialize a new run with a fresh Croaker
func start_new_run(croaker_name: String = "Player Frog") -> void:
	print("[GameManager] Starting new run with Croaker: '%s'" % croaker_name)
	
	# Clear any previous race results when starting fresh
	clear_race_results()
	races_completed = 0
	
	# Create player's Croaker - for now, use a specific starter car
	# You could make this selectable in the future
	current_croaker = create_croaker_from_data(croaker_name, "toytoada", "coroalla")
	if not current_croaker:
		# Fallback if JSON loading failed
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

# Clear race results data
func clear_race_results() -> void:
	last_race_results.clear()
	last_race_position = 0
	print("[GameManager] Race results cleared")

# Generate AI opponents for the run using croakers.json data
func _generate_ai_croakers() -> void:
	ai_croakers.clear()
	
	# AI names for variety
	var ai_names = ["Speed Demon", "Road Warrior", "Track Master"]
	
	# Create 3 AI opponents with different brands/models
	for i in range(3):
		var ai_name = ai_names[i % ai_names.size()]
		var brand_model = get_random_brand_model()
		
		if brand_model.brand_id != "" and brand_model.model_id != "":
			var ai_croaker = create_croaker_from_data(ai_name, brand_model.brand_id, brand_model.model_id)
			if ai_croaker:
				ai_croakers.append(ai_croaker)
				continue
		
		# Fallback: create basic AI croaker if JSON loading failed
		print("[GameManager] Fallback: Creating basic AI croaker %s" % ai_name)
		var ai = Croaker.new(ai_name)
		ai.jump_distance = randf_range(4.5, 6.5)
		ai.action_delay = randf_range(0.8, 1.2)
		ai.stamina = randf_range(80.0, 120.0)
		ai_croakers.append(ai)
	
	print("[GameManager] Generated %d AI Croakers" % ai_croakers.size())

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
		print("  Brand/Model: %s %s" % [current_croaker.get_brand_name(), current_croaker.get_model_name()])
		print("  Jump Distance: %.1f" % current_croaker.jump_distance)
		print("  Action Delay: %.1f" % current_croaker.action_delay)
		print("  Stamina: %.1f" % current_croaker.stamina)
		print("  Personality: %s" % current_croaker.personality)
		print("  Upgrades: %d" % current_croaker.upgrades_equipped.size())
		print("  Warts: %d" % current_croaker.warts_equipped.size())
	else:
		print("[GameManager] No current Croaker")

# Debug function to print last race results
func debug_print_race_results() -> void:
	if last_race_results.is_empty():
		print("[GameManager] No race results to display")
		return
	
	print("[GameManager] Last Race Results:")
	for i in range(last_race_results.size()):
		var croaker = last_race_results[i]
		var player_indicator = " (PLAYER)" if croaker == current_croaker else ""
		print("  %d. %s%s (%s %s) - Jump: %.1f, Delay: %.1f" % [
			i + 1,
			croaker.name,
			player_indicator,
			croaker.get_brand_name(),
			croaker.get_model_name(),
			croaker.jump_distance,
			croaker.action_delay
		])
