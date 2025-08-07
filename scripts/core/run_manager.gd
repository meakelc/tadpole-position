# run_manager.gd - AutoLoad Singleton for Run State Management
# Handles all run-specific game state, race results, and Croaker management
extends Node

# =============================
# RUN STATE
# =============================

# Current run data
var current_croaker: Croaker = null
var ai_croakers: Array[Croaker] = []
var eliminated_croakers: Array[Croaker] = []  # NEW: Track eliminated racers
var races_completed: int = 0
var current_run_active: bool = false

# Race results storage
var race_history: Array[Dictionary] = []  # Full race history for the run

# Run configuration
const DEFAULT_AI_COUNT := 15
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
	eliminated_croakers.clear()  # NEW: Clear elimination list
	RaceManager.clear_race_results()
	
	print("[RunManager] New run started successfully")
	print("[RunManager] Active racers: %d (Player + %d AI)" % [get_active_croakers().size(), ai_croakers.size()])
	debug_print_croaker_stats()
	return true

func end_current_run() -> void:
	"""Clean up current run state"""
	print("[RunManager] Ending current run")
	
	current_croaker = null
	ai_croakers.clear()
	eliminated_croakers.clear()  # NEW: Clear elimination tracking
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
	if not current_croaker:
		return false
	
	# Check if player is in eliminated list
	return current_croaker in eliminated_croakers

# =============================
# ELIMINATION TRACKING (NEW)
# =============================

func get_active_croakers() -> Array[Croaker]:
	"""
	Get all racers that are still active (not eliminated)
	Returns player + active AI croakers
	"""
	var active_croakers: Array[Croaker] = []
	
	# Add player if not eliminated
	if current_croaker and current_croaker not in eliminated_croakers:
		active_croakers.append(current_croaker)
	
	# Add AI croakers that aren't eliminated
	for ai_croaker in ai_croakers:
		if ai_croaker not in eliminated_croakers:
			active_croakers.append(ai_croaker)
	
	return active_croakers

func eliminate_croakers(croakers_to_eliminate: Array[Croaker]) -> void:
	"""
	Move croakers from active to eliminated status
	Input: Array of croakers to eliminate after elimination race
	"""
	if croakers_to_eliminate.is_empty():
		print("[RunManager] No croakers to eliminate")
		return
	
	print("[RunManager] Eliminating %d croakers:" % croakers_to_eliminate.size())
	
	for croaker in croakers_to_eliminate:
		if croaker not in eliminated_croakers:
			eliminated_croakers.append(croaker)
			print("[RunManager] - Eliminated: %s (%s)" % [croaker.name, croaker.get_full_type_name()])
			
			# Special logging for player elimination
			if croaker == current_croaker:
				print("[RunManager] *** PLAYER ELIMINATED ***")
	
	var active_count = get_active_croakers().size()
	var eliminated_count = eliminated_croakers.size()
	print("[RunManager] Tournament status: %d active, %d eliminated" % [active_count, eliminated_count])
	
	# Validate expected elimination counts
	_validate_elimination_counts()

func get_eliminated_croakers() -> Array[Croaker]:
	"""Get list of all eliminated croakers"""
	return eliminated_croakers.duplicate()

func is_croaker_eliminated(croaker: Croaker) -> bool:
	"""Check if a specific croaker has been eliminated"""
	return croaker in eliminated_croakers

func get_elimination_summary() -> Dictionary:
	"""Get summary of elimination status"""
	var total_croakers = 1 + ai_croakers.size()  # Player + AI
	var active_count = get_active_croakers().size()
	var eliminated_count = eliminated_croakers.size()
	
	return {
		"total_croakers": total_croakers,
		"active_count": active_count,
		"eliminated_count": eliminated_count,
		"player_active": current_croaker and not is_croaker_eliminated(current_croaker),
		"expected_next_elimination": _get_expected_elimination_count()
	}

func _validate_elimination_counts() -> void:
	"""Validate that elimination counts match expected tournament progression"""
	var active_count = get_active_croakers().size()
	var round_number = (races_completed + 2) / 3  # Which elimination round we just completed
	
	var expected_counts = [16, 12, 8, 4]  # Expected active count after each elimination
	
	if round_number >= 1 and round_number <= 4:
		var expected_active = expected_counts[round_number - 1]
		if active_count != expected_active:
			print("[RunManager] WARNING: Unexpected active count after round %d elimination" % round_number)
			print("[RunManager] Expected: %d active, Actual: %d active" % [expected_active, active_count])

func _get_expected_elimination_count() -> int:
	"""Get expected number of eliminations for next elimination race"""
	var next_elimination_race = ((races_completed / 3) + 1) * 3
	
	match next_elimination_race:
		3: return 4   # 16 → 12
		6: return 4   # 12 → 8  
		9: return 4   # 8 → 4
		_: return 0   # No more eliminations

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

# Enhanced _generate_ai_croakers() method for run_manager.gd
func _generate_ai_croakers() -> bool:
	"""Generate AI opponents for the current run using croaker data"""
	ai_croakers.clear()
	
	if not GameManager or not GameManager.croaker_data.has("brands"):
		print("[RunManager] WARNING: Using fallback AI generation")
		return _generate_fallback_ai_croakers()
	
	# Expanded AI names for 15+ unique opponents
	var ai_names = [
		"Speed Demon", "Road Warrior", "Track Master", "Circuit King", "Jump Master",
		"Thunder Hop", "Velocity Viper", "Racing Rocket", "Turbo Toad", "Flash Frog",
		"Blazing Baron", "Swift Shadow", "Lightning Leap", "Power Prowler", "Dash Duke",
		"Storm Striker", "Rapid Rebel", "Zoom Zephyr", "Bullet Bounce", "Nitro Knight",
		"Sonic Speedster", "Warp Warrior", "Hyper Hopper", "Mega Mover", "Ultra Ace"
	]
	
	# Shuffle names to ensure variety
	ai_names.shuffle()
	
	# Get all available brand/model combinations for variety
	var available_combinations: Array[Dictionary] = []
	var brands = GameManager.croaker_data.brands
	
	for brand_id in brands.keys():
		var brand_data = brands[brand_id]
		if brand_data.has("models"):
			for model_id in brand_data.models.keys():
				available_combinations.append({
					"brand_id": brand_id,
					"model_id": model_id
				})
	
	# Shuffle combinations to ensure variety
	available_combinations.shuffle()
	
	print("[RunManager] Found %d brand/model combinations for AI generation" % available_combinations.size())
	
	# Create AI opponents with diverse brands/models
	for i in range(DEFAULT_AI_COUNT):
		var ai_name = ai_names[i % ai_names.size()]
		
		# Ensure no duplicate names by adding suffix if needed
		var original_name = ai_name
		var name_suffix = 1
		while _is_name_taken(ai_name):
			ai_name = "%s %d" % [original_name, name_suffix]
			name_suffix += 1
		
		# Select brand/model combination with variety
		var brand_model: Dictionary
		if not available_combinations.is_empty():
			# Use combinations in order to ensure variety, cycle through if we need more than available
			brand_model = available_combinations[i % available_combinations.size()]
		else:
			# Fallback to random selection
			brand_model = _get_random_brand_model()
		
		# Create AI croaker
		if brand_model.brand_id != "" and brand_model.model_id != "":
			var ai_croaker = create_croaker_from_data(ai_name, brand_model.brand_id, brand_model.model_id)
			if ai_croaker:
				ai_croakers.append(ai_croaker)
				print("[RunManager] Created AI #%d: %s (%s %s)" % [
					i + 1, ai_croaker.name, ai_croaker.get_brand_name(), ai_croaker.get_model_name()
				])
				continue
		
		# Fallback if specific creation failed
		print("[RunManager] Fallback: Creating basic AI croaker %s" % ai_name)
		var ai = _create_fallback_croaker(ai_name)
		ai.jump_distance = randf_range(4.0, 7.0)  # Wider range for more variety
		ai.action_delay = randf_range(0.7, 1.3)   # Wider range for more variety
		ai.stamina = randf_range(75.0, 125.0)     # Wider range for more variety
		
		# Add some random personality variety for fallback AIs
		var personalities = ["aggressive", "steady", "efficient", "powerful", "sporty"]
		ai.personality = personalities[randi() % personalities.size()]
		
		ai_croakers.append(ai)
	
	print("[RunManager] Generated %d AI Croakers with diverse stats and brands" % ai_croakers.size())
	
	# Debug: Print brand variety statistics
	_debug_print_ai_variety()
	
	return ai_croakers.size() == DEFAULT_AI_COUNT

func _generate_fallback_ai_croakers() -> bool:
	"""Generate basic AI croakers if GameManager data is unavailable"""
	ai_croakers.clear()
	
	# Use the same expanded names for fallback
	var ai_names = [
		"Speed Demon", "Road Warrior", "Track Master", "Circuit King", "Jump Master",
		"Thunder Hop", "Velocity Viper", "Racing Rocket", "Turbo Toad", "Flash Frog",
		"Blazing Baron", "Swift Shadow", "Lightning Leap", "Power Prowler", "Dash Duke"
	]
	
	for i in range(DEFAULT_AI_COUNT):
		var ai_name = ai_names[i % ai_names.size()]
		
		# Ensure unique names
		var original_name = ai_name
		var name_suffix = 1
		while _is_name_taken(ai_name):
			ai_name = "%s %d" % [original_name, name_suffix]
			name_suffix += 1
		
		var ai = _create_fallback_croaker(ai_name)
		ai.jump_distance = randf_range(4.0, 7.0)
		ai.action_delay = randf_range(0.7, 1.3)
		ai.stamina = randf_range(75.0, 125.0)
		
		# Add personality variety
		var personalities = ["aggressive", "steady", "efficient", "powerful", "sporty"]
		ai.personality = personalities[randi() % personalities.size()]
		
		ai_croakers.append(ai)
	
	print("[RunManager] Generated %d fallback AI Croakers" % ai_croakers.size())
	return true

func _is_name_taken(croaker_name: String) -> bool:
	"""Check if a name is already taken by existing AI croakers or player"""
	
	# Check against player croaker
	if current_croaker and current_croaker.name == croaker_name:
		return true
	
	# Check against existing AI croakers
	for ai in ai_croakers:
		if ai.name == croaker_name:
			return true
	
	return false

func _debug_print_ai_variety() -> void:
	"""Debug function to print AI brand/model variety statistics"""
	if ai_croakers.is_empty():
		return
	
	var brand_count: Dictionary = {}
	var model_count: Dictionary = {}
	var personality_count: Dictionary = {}
	
	for ai in ai_croakers:
		# Count brands
		var brand = ai.get_brand_name()
		brand_count[brand] = brand_count.get(brand, 0) + 1
		
		# Count models
		var model = ai.get_full_type_name()
		model_count[model] = model_count.get(model, 0) + 1
		
		# Count personalities
		personality_count[ai.personality] = personality_count.get(ai.personality, 0) + 1
	
	print("[RunManager] === AI VARIETY STATISTICS ===")
	print("Total AI Croakers: %d" % ai_croakers.size())
	print("Brand Distribution: %s" % brand_count)
	print("Personality Distribution: %s" % personality_count)
	print("Unique Models: %d" % model_count.size())
	print("===========================================")

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
		print("  Status: %s" % ("ELIMINATED" if _is_player_eliminated() else "ACTIVE"))
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
	
	# NEW: Enhanced debug info with elimination tracking
	var elimination_summary = get_elimination_summary()
	print("Tournament Status: %d active, %d eliminated (of %d total)" % [
		elimination_summary.active_count,
		elimination_summary.eliminated_count,
		elimination_summary.total_croakers
	])
	print("Player Status: %s" % ("ACTIVE" if elimination_summary.player_active else "ELIMINATED"))
	
	if is_run_active():
		var stats = get_run_stats()
		print("Wins: %d | Podiums: %d | Avg Position: %.1f" % [
			stats.wins, stats.podium_finishes, stats.average_position
		])
	
	print("=================================")

func debug_print_elimination_status() -> void:
	"""NEW: Debug function to print detailed elimination status"""
	print("[RunManager] === ELIMINATION STATUS ===")
	
	var active_croakers = get_active_croakers()
	var eliminated = get_eliminated_croakers()
	
	print("ACTIVE RACERS (%d):" % active_croakers.size())
	for i in range(active_croakers.size()):
		var croaker = active_croakers[i]
		var player_marker = " ★" if croaker == current_croaker else ""
		print("  %d. %s%s (%s)" % [i + 1, croaker.name, player_marker, croaker.get_full_type_name()])
	
	if not eliminated.is_empty():
		print("ELIMINATED RACERS (%d):" % eliminated.size())
		for i in range(eliminated.size()):
			var croaker = eliminated[i]
			var player_marker = " ★" if croaker == current_croaker else ""
			print("  %s%s (%s)" % [croaker.name, player_marker, croaker.get_full_type_name()])
	
	print("===================================")

func debug_print_all() -> void:
	"""Print all debug information"""
	debug_print_run_state()
	debug_print_croaker_stats()
	debug_print_elimination_status()  # NEW: Include elimination status
