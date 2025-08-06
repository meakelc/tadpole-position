# run_manager.gd - AutoLoad Singleton for Run State Management
# Handles all run-specific game state, race results, and Croaker management
extends Node

# =============================
# RUN STATE
# =============================

# Current run data
var current_croaker: Croaker = null
var ai_croakers: Array[Croaker] = []
var races_completed: int = 0
var current_run_active: bool = false

# Race results storage
var race_history: Array[Dictionary] = []  # Full race history for the run

# Run configuration
const DEFAULT_AI_COUNT := 3
const MAX_RACES_PER_RUN := 9  # 3 rounds of 3 races each

# =============================
# RUN LIFECYCLE
# =============================

func _ready() -> void:
	print("[RunManager] RunManager singleton initialized")
	_validate_dependencies()

func _validate_dependencies() -> void:
	"""Ensure GameManager is available"""
	if not GameManager:
		print("[RunManager] ERROR: GameManager not found! Ensure it's loaded as AutoLoad before RunManager")

# Start a new run with a fresh Croaker
func start_new_run(croaker_name: String = "Player Frog", brand_id: String = "", model_id: String = "") -> bool:
	"""
	Start a new run with a fresh Croaker
	If brand_id/model_id are empty, uses default starter car
	Returns true if successful, false if failed
	"""
	print("[RunManager] Starting new run with Croaker: '%s'" % croaker_name)
	
	# Clear any existing run state
	end_current_run()
	
	# Create player's Croaker
	if brand_id == "" or model_id == "":
		# Use default starter car
		current_croaker = create_croaker_from_data(croaker_name, "toytoada", "coroalla")
	else:
		current_croaker = create_croaker_from_data(croaker_name, brand_id, model_id)
	
	if not current_croaker:
		print("[RunManager] ERROR: Failed to create player Croaker")
		return false
	
	# Generate AI opponents
	if not _generate_ai_croakers():
		print("[RunManager] ERROR: Failed to generate AI opponents")
		return false
	
	# Initialize run state
	races_completed = 0
	current_run_active = true
	RaceManager.clear_race_results()
	
	print("[RunManager] New run started successfully")
	debug_print_croaker_stats()
	return true

func end_current_run() -> void:
	"""Clean up current run state"""
	print("[RunManager] Ending current run")
	
	current_croaker = null
	ai_croakers.clear()
	races_completed = 0
	current_run_active = false
	RaceManager.clear_race_results()
	race_history.clear()

func is_run_active() -> bool:
	"""Check if there's an active run"""
	return current_run_active and current_croaker != null

func is_run_complete() -> bool:
	"""Check if the current run is complete (won or eliminated)"""
	if not is_run_active():
		return false
	
	# Run is complete if we've finished all races or been eliminated
	return races_completed >= MAX_RACES_PER_RUN or _is_player_eliminated()

func _on_race_completed(results, last_race_position) -> void:
	# Increment race counter
	races_completed += 1
	
	# Store in race history
	var race_record = {
		"race_number": races_completed,
		"results": results.duplicate(),
		"player_position": last_race_position,
		"was_elimination": (races_completed % 3 == 0)
	}
	race_history.append(race_record)

func _is_player_eliminated() -> bool:
	"""Check if player was eliminated in the last elimination race"""
	if RaceManager.last_race_results.is_empty():
		return false
	
	# Check if last race was elimination and player finished poorly
	var was_elimination = (races_completed % 3 == 0)
	var player_position = RaceManager.get_last_race_player_position()
	
	return was_elimination and player_position > 2  # Bottom 2 eliminated

# =============================
# CROAKER MANAGEMENT
# =============================

func create_croaker_from_data(croaker_name: String, brand_id: String, model_id: String) -> Croaker:
	"""
	Create a Croaker using data from GameManager's croaker configuration
	Returns null if creation fails
	"""
	if not GameManager or not GameManager.croaker_data.has("brands"):
		print("[RunManager] ERROR: GameManager croaker data not available")
		return _create_fallback_croaker(croaker_name)
	
	var brands = GameManager.croaker_data.brands
	
	if not brands.has(brand_id):
		print("[RunManager] ERROR: Brand '%s' not found in croaker data" % brand_id)
		return _create_fallback_croaker(croaker_name)
	
	var brand_data = brands[brand_id]
	if not brand_data.has("models") or not brand_data.models.has(model_id):
		print("[RunManager] ERROR: Model '%s' not found in brand '%s'" % [model_id, brand_id])
		return _create_fallback_croaker(croaker_name)
	
	var model_data = brand_data.models[model_id]
	var base_stats = model_data.base_stats
	
	# Create the Croaker
	var croaker = Croaker.new(croaker_name)
	
	# Apply base stats with variance
	var variance = GameManager.croaker_data.get("stat_variance", {})
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
	
	print("[RunManager] Created Croaker: %s (%s %s) - Jump: %.1f, Delay: %.1f, Personality: %s" % [
		croaker.name,
		croaker.brand_name,
		croaker.model_name,
		croaker.jump_distance,
		croaker.action_delay,
		croaker.personality
	])
	
	return croaker

func _create_fallback_croaker(croaker_name: String) -> Croaker:
	"""Create a basic fallback Croaker if JSON data fails"""
	print("[RunManager] Creating fallback Croaker: %s" % croaker_name)
	
	var croaker = Croaker.new(croaker_name)
	croaker.jump_distance = 5.0
	croaker.action_delay = 1.0
	croaker.stamina = 100.0
	croaker.brand_name = "Generic"
	croaker.model_name = "Starter"
	croaker.personality = "steady"
	
	return croaker

func _apply_stat_variance(base_value: float, variance: float) -> float:
	"""Apply random variance to a base stat value"""
	if variance <= 0.0:
		return base_value
	
	var min_val = base_value - variance
	var max_val = base_value + variance
	return randf_range(min_val, max_val)

func _generate_ai_croakers() -> bool:
	"""Generate AI opponents for the current run using croaker data"""
	ai_croakers.clear()
	
	if not GameManager or not GameManager.croaker_data.has("brands"):
		print("[RunManager] WARNING: Using fallback AI generation")
		return _generate_fallback_ai_croakers()
	
	# AI names for variety
	var ai_names = ["Speed Demon", "Road Warrior", "Track Master", "Circuit King", "Jump Master"]
	ai_names.shuffle()
	
	# Create AI opponents with different brands/models
	for i in range(DEFAULT_AI_COUNT):
		var ai_name = ai_names[i % ai_names.size()]
		var brand_model = _get_random_brand_model()
		
		if brand_model.brand_id != "" and brand_model.model_id != "":
			var ai_croaker = create_croaker_from_data(ai_name, brand_model.brand_id, brand_model.model_id)
			if ai_croaker:
				ai_croakers.append(ai_croaker)
				continue
		
		# Fallback if specific creation failed
		print("[RunManager] Fallback: Creating basic AI croaker %s" % ai_name)
		var ai = _create_fallback_croaker(ai_name)
		ai.jump_distance = randf_range(4.5, 6.5)
		ai.action_delay = randf_range(0.8, 1.2)
		ai.stamina = randf_range(80.0, 120.0)
		ai_croakers.append(ai)
	
	print("[RunManager] Generated %d AI Croakers" % ai_croakers.size())
	return ai_croakers.size() == DEFAULT_AI_COUNT

func _generate_fallback_ai_croakers() -> bool:
	"""Generate basic AI croakers if GameManager data is unavailable"""
	ai_croakers.clear()
	
	var ai_names = ["Speed Demon", "Road Warrior", "Track Master"]
	
	for i in range(DEFAULT_AI_COUNT):
		var ai_name = ai_names[i % ai_names.size()]
		var ai = _create_fallback_croaker(ai_name)
		ai.jump_distance = randf_range(4.5, 6.5)
		ai.action_delay = randf_range(0.8, 1.2)
		ai.stamina = randf_range(80.0, 120.0)
		ai_croakers.append(ai)
	
	print("[RunManager] Generated %d fallback AI Croakers" % ai_croakers.size())
	return true

func _get_random_brand_model() -> Dictionary:
	"""Get a random brand and model combination from GameManager data"""
	if not GameManager or not GameManager.croaker_data.has("brands"):
		return {"brand_id": "", "model_id": ""}
	
	var brands = GameManager.croaker_data.brands
	if brands.is_empty():
		return {"brand_id": "", "model_id": ""}
	
	var brand_keys = brands.keys()
	var random_brand_id = brand_keys[randi() % brand_keys.size()]
	var brand_data = brands[random_brand_id]
	
	if not brand_data.has("models") or brand_data.models.is_empty():
		return {"brand_id": "", "model_id": ""}
	
	var model_keys = brand_data.models.keys()
	var random_model_id = model_keys[randi() % model_keys.size()]
	
	return {
		"brand_id": random_brand_id,
		"model_id": random_model_id
	}

# =============================
# CROAKER UPGRADES
# =============================

func apply_upgrade(upgrade_type: String, value: float) -> bool:
	"""
	Apply an upgrade to the current Croaker
	Returns true if successful, false if failed
	"""
	if not current_croaker:
		print("[RunManager] ERROR: No current Croaker to upgrade")
		return false
	
	match upgrade_type:
		"jump_distance":
			current_croaker.jump_distance += value
			current_croaker.jump_distance = max(0.1, current_croaker.jump_distance)  # Min cap
			print("[RunManager] Applied jump upgrade: +%.1f (new total: %.1f)" % [
				value, current_croaker.jump_distance
			])
			return true
			
		"action_delay":
			current_croaker.action_delay += value  # Negative values make it faster
			current_croaker.action_delay = max(0.1, current_croaker.action_delay)  # Min cap
			print("[RunManager] Applied speed upgrade: %.1f (new delay: %.1f)" % [
				value, current_croaker.action_delay
			])
			return true
			
		"stamina":
			current_croaker.stamina += value
			current_croaker.stamina = max(1.0, current_croaker.stamina)  # Min cap
			print("[RunManager] Applied stamina upgrade: +%.1f (new total: %.1f)" % [
				value, current_croaker.stamina
			])
			return true
			
		_:
			print("[RunManager] ERROR: Unknown upgrade type: %s" % upgrade_type)
			return false

func can_apply_upgrade(upgrade_type: String, value: float) -> bool:
	"""Check if an upgrade can be applied without breaking stat limits"""
	if not current_croaker:
		return false
	
	match upgrade_type:
		"jump_distance":
			return (current_croaker.jump_distance + value) >= 0.1
		"action_delay":
			return (current_croaker.action_delay + value) >= 0.1
		"stamina":
			return (current_croaker.stamina + value) >= 1.0
		_:
			return false

# =============================
# RACE MANAGEMENT
# =============================
func get_current_race_number() -> int:
	"""Get the current race number (1-indexed)"""
	return races_completed + 1

func is_next_race_elimination() -> bool:
	"""Check if the next race will be an elimination race"""
	return (get_current_race_number() % 3) == 0

func get_races_until_elimination() -> int:
	"""Get number of races until next elimination"""
	var next_race = get_current_race_number()
	return 3 - (next_race % 3) if (next_race % 3) != 0 else 0

# =============================
# RUN STATISTICS
# =============================

func get_run_stats() -> Dictionary:
	"""Get comprehensive run statistics"""
	if not is_run_active():
		return {}
	
	var stats = {
		"croaker_name": current_croaker.name,
		"croaker_type": current_croaker.get_full_type_name(),
		"races_completed": races_completed,
		"races_remaining": max(0, MAX_RACES_PER_RUN - races_completed),
		"elimination_races": 0,
		"wins": 0,
		"podium_finishes": 0,
		"average_position": 0.0,
		"is_eliminated": _is_player_eliminated(),
		"is_complete": is_run_complete()
	}
	
	# Calculate statistics from race history
	if not race_history.is_empty():
		var total_position = 0
		for race in race_history:
			total_position += race.player_position
			
			if race.was_elimination:
				stats.elimination_races += 1
			
			if race.player_position == 1:
				stats.wins += 1
			
			if race.player_position <= 3:
				stats.podium_finishes += 1
		
		stats.average_position = float(total_position) / race_history.size()
	
	return stats

func get_race_history() -> Array[Dictionary]:
	"""Get complete race history for the current run"""
	return race_history.duplicate()

# =============================
# DEBUG METHODS
# =============================

func debug_print_croaker_stats() -> void:
	"""Debug function to print current Croaker stats"""
	if current_croaker:
		print("[RunManager] === CURRENT CROAKER STATS ===")
		print("  Name: %s" % current_croaker.name)
		print("  Brand/Model: %s %s" % [current_croaker.get_brand_name(), current_croaker.get_model_name()])
		print("  Jump Distance: %.1f" % current_croaker.jump_distance)
		print("  Action Delay: %.1f" % current_croaker.action_delay)
		print("  Stamina: %.1f" % current_croaker.stamina)
		print("  Personality: %s" % current_croaker.personality)
		print("  Upgrades: %d" % current_croaker.upgrades_equipped.size())
		print("  Warts: %d" % current_croaker.warts_equipped.size())
		print("================================")
	else:
		print("[RunManager] No current Croaker")

func debug_print_run_state() -> void:
	"""Debug function to print complete run state"""
	print("[RunManager] === RUN STATE DEBUG ===")
	print("Run Active: %s" % is_run_active())
	print("Races Completed: %d/%d" % [races_completed, MAX_RACES_PER_RUN])
	print("Next Race: #%d (%s)" % [
		get_current_race_number(),
		"ELIMINATION" if is_next_race_elimination() else "Regular"
	])
	print("AI Opponents: %d" % ai_croakers.size())
	
	if is_run_active():
		var stats = get_run_stats()
		print("Wins: %d | Podiums: %d | Avg Position: %.1f" % [
			stats.wins, stats.podium_finishes, stats.average_position
		])
	
	print("=================================")

func debug_print_all() -> void:
	"""Print all debug information"""
	debug_print_run_state()
	debug_print_croaker_stats()
