# game_manager.gd - AutoLoad Singleton
# Handles scene management, global game data loading, and persistent game systems
# NOT responsible for run-specific state - that's handled by RunManager
extends Node

# =============================
# SCENE MANAGEMENT
# =============================

# Current scene reference
var current_scene: Node = null

# =============================
# GAME DATA
# =============================

# Croaker Data - Loaded from JSON and shared with other systems
var croaker_data: Dictionary = {}

func _ready() -> void:
	# Get the current scene (should be Main.tscn initially)
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	print("[GameManager] Initial scene loaded: ", current_scene.name)
	
	# Load croaker data from JSON
	_load_croaker_data()

# =============================
# CROAKER DATA LOADING
# =============================

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

# =============================
# CROAKER DATA ACCESS
# =============================

# Get the loaded croaker data (for use by other systems like RunManager)
func get_croaker_data() -> Dictionary:
	"""
	Get the loaded croaker data dictionary
	Returns empty dict if data failed to load
	Used by RunManager and other systems that need croaker configuration
	"""
	return croaker_data

# Get a random brand and model combination from loaded data
func get_random_brand_model() -> Dictionary:
	"""
	Get a random brand and model combination
	Returns: {"brand_id": String, "model_id": String}
	Returns empty strings if no data available
	"""
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

# Check if a specific brand and model exist in the data
func has_brand_model(brand_id: String, model_id: String) -> bool:
	"""Check if a specific brand and model combination exists in the loaded data"""
	if not croaker_data.has("brands"):
		return false
	
	var brands = croaker_data.brands
	if not brands.has(brand_id):
		return false
	
	var brand_data = brands[brand_id]
	if not brand_data.has("models"):
		return false
	
	return brand_data.models.has(model_id)

# Get brand display name
func get_brand_display_name(brand_id: String) -> String:
	"""Get the display name for a brand ID"""
	if not croaker_data.has("brands") or not croaker_data.brands.has(brand_id):
		return "Unknown Brand"
	
	return croaker_data.brands[brand_id].get("display_name", "Unknown Brand")

# Get model display name
func get_model_display_name(brand_id: String, model_id: String) -> String:
	"""Get the display name for a specific model"""
	if not has_brand_model(brand_id, model_id):
		return "Unknown Model"
	
	return croaker_data.brands[brand_id].models[model_id].get("display_name", "Unknown Model")

# =============================
# SCENE MANAGEMENT
# =============================

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
