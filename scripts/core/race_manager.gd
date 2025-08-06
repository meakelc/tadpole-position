# race_manager.gd - AutoLoad Singleton for Race Management
# Handles all race-related functionality independent of runs
# Supports run races, challenge races, trial races, and any future race types
extends Node

# =============================
# RACE STATE PROPERTIES
# =============================

# Current race identification and configuration
var current_race_type: String = ""  # "run_race", "challenge_race", "trial_race"
var current_race_config: Dictionary = {}  # Race-specific settings
var race_in_progress: bool = false

# Race participants
var current_racers: Array[Croaker] = []  # All participants in current race

# Race results storage
var last_race_results: Array[Croaker] = []  # All racers in finishing order
var last_race_player_position: int = 0  # Player's finishing position (1-indexed)

# =============================
# RACE CONFIGURATION CONSTANTS
# =============================

# Default race configurations for different race types
const DEFAULT_CONFIGS = {
	"run_race": {
		"max_racers": 4,
		"track_length": 100.0,
		"elimination_enabled": false,
		"ai_difficulty": "normal",
		"allow_wart_rewards": true
	},
	"challenge_race": {
		"max_racers": 4,
		"track_length": 150.0,
		"elimination_enabled": false,
		"ai_difficulty": "hard",
		"allow_wart_rewards": false
	},
	"trial_race": {
		"max_racers": 2,
		"track_length": 75.0,
		"elimination_enabled": false,
		"ai_difficulty": "easy",
		"allow_wart_rewards": false
	}
}

# AI difficulty modifiers
const AI_DIFFICULTY_MODIFIERS = {
	"easy": {
		"stat_variance": 0.15,  # Low variance = more predictable
		"stat_multiplier": 0.85,  # Slightly weaker stats
		"personality_bias": "steady"
	},
	"normal": {
		"stat_variance": 0.25,
		"stat_multiplier": 1.0,
		"personality_bias": "mixed"
	},
	"hard": {
		"stat_variance": 0.20,  # Lower variance = more consistent threat
		"stat_multiplier": 1.15,  # Stronger stats
		"personality_bias": "aggressive"
	},
	"extreme": {
		"stat_variance": 0.10,  # Very consistent
		"stat_multiplier": 1.3,  # Much stronger
		"personality_bias": "aggressive"
	}
}

# =============================
# SINGLETON INITIALIZATION
# =============================

func _ready() -> void:
	print("[RaceManager] RaceManager singleton initialized")
	_validate_dependencies()

func _validate_dependencies() -> void:
	"""Ensure required dependencies are available"""
	if not GameManager:
		print("[RaceManager] WARNING: GameManager not found! AI generation may fail.")
	else:
		print("[RaceManager] GameManager dependency validated")

# =============================
# CORE RACE MANAGEMENT
# =============================
func config_current_race(player_croaker: Croaker, ai_croakers: Array[Croaker], race_type: String = "run_race", config: Dictionary = {}) -> String:
	# Validate race type
	if not race_type in DEFAULT_CONFIGS:
		print("[RaceManager] WARNING: Unknown race type '%s', using 'run_race'" % race_type)
		race_type = "run_race"
	
	# Set up race configuration
	current_race_type = race_type
	current_race_config = get_default_race_config(race_type)
	
	# Set up race participants
	current_racers.clear()
	current_racers.append(player_croaker)
	current_racers.append_array(ai_croakers)
	
	# Validate racer count
	if current_racers.size() > current_race_config.max_racers:
		print("[RaceManager] ERROR: Too many racers (%d > %d max)" % [
			current_racers.size(), current_race_config.max_racers
		])
		assert(false)
	
	# Merge custom config
	for key in config:
		current_race_config[key] = config[key]
	
	# Validate final configuration
	if not validate_race_config(current_race_config):
		print("[RaceManager] ERROR: Invalid race configuration")
		assert(false)
	
	return current_race_type 

func start_race(player_croaker: Croaker, ai_croakers: Array[Croaker]) -> bool:
	"""
	Start a new race with specified participants and configuration
	Returns true if successful, false if failed
	"""
	if race_in_progress:
		print("[RaceManager] ERROR: Cannot start race - race already in progress")
		return false
	
	if not player_croaker:
		print("[RaceManager] ERROR: Cannot start race - no player Croaker provided")
		return false
	
	if ai_croakers.is_empty():
		print("[RaceManager] ERROR: Cannot start race - no AI opponents provided")
		return false
	
	# Initialize race state
	race_in_progress = true
	clear_race_results()
	
	# Reset all racers' race state
	for croaker in current_racers:
		croaker.reset_race_state()
	
	print("[RaceManager] Started race with %d racers (Player: %s)" % [
		current_racers.size(), player_croaker.name
	])
	
	debug_print_race_setup()
	return true

func end_race(results: Array[Croaker]) -> bool:
	"""
	End the current race and store results
	Returns true if successful, false if failed
	"""
	if not race_in_progress:
		print("[RaceManager] WARNING: Attempting to end race when no race in progress")
		return false
	
	if results.is_empty():
		print("[RaceManager] ERROR: Cannot end race with empty results")
		return false
	
	# Store race results
	store_race_results(results)
	
	# Clean up race state
	race_in_progress = false
	
	print("[RaceManager] Race ended - %s won!" % results[0].name)
	debug_print_race_results()
	return true

func clear_race_state() -> void:
	"""Clear all race state data"""
	current_race_type = ""
	current_race_config.clear()
	current_racers.clear()
	race_in_progress = false
	clear_race_results()
	print("[RaceManager] Race state cleared")

func is_race_active() -> bool:
	"""Check if there's an active race"""
	return race_in_progress and not current_racers.is_empty()

# =============================
# RACE RESULTS MANAGEMENT
# =============================

func store_race_results(results: Array[Croaker]) -> void:
	"""Store race results and calculate player position"""
	if results.is_empty():
		print("[RaceManager] ERROR: Cannot store empty race results")
		return
	
	# Store results
	last_race_results = results.duplicate()
	
	# Find player position (assumes first racer in current_racers is player)
	var player_croaker = current_racers[0] if not current_racers.is_empty() else null
	
	if player_croaker:
		last_race_player_position = results.find(player_croaker) + 1
		if last_race_player_position == 0:  # Player not found in results
			print("[RaceManager] WARNING: Player not found in race results")
			last_race_player_position = results.size()  # Assume last place
	else:
		last_race_player_position = 0
	
	print("[RaceManager] Race results stored - Player finished %d/%d" % [
		last_race_player_position, results.size()
	])

func get_last_race_results() -> Array[Croaker]:
	"""Get the last race results array"""
	return last_race_results.duplicate()

func get_last_race_player_position() -> int:
	"""Get player's position in the last race (1-indexed)"""
	return last_race_player_position

func get_race_winner() -> Croaker:
	"""Get the winner of the last race"""
	if last_race_results.is_empty():
		return null
	return last_race_results[0]

func clear_race_results() -> void:
	"""Clear race results data"""
	last_race_results.clear()
	last_race_player_position = 0

# =============================
# AI OPPONENT GENERATION
# =============================

func generate_ai_opponents(count: int = 3, difficulty: String = "normal", exclude_brands: Array = []) -> Array[Croaker]:
	"""
	Generate AI opponents for any race type
	Returns array of AI Croakers, empty array if generation fails
	"""
	var ai_croakers: Array[Croaker] = []
	
	if not GameManager or not GameManager.croaker_data.has("brands"):
		print("[RaceManager] WARNING: Using fallback AI generation")
		return _generate_fallback_ai_opponents(count, difficulty)
	
	# AI names pool
	var ai_names = [
		"Speed Demon", "Road Warrior", "Track Master", "Circuit King", "Jump Master",
		"Lightning Bolt", "Thunder Frog", "Rocket Rider", "Turbo Toad", "Sprint Star",
		"Velocity Viper", "Dash Devil", "Quick Silver", "Flash Frog", "Zoom Zapper"
	]
	ai_names.shuffle()
	
	# Get difficulty modifiers
	var diff_mod = AI_DIFFICULTY_MODIFIERS.get(difficulty, AI_DIFFICULTY_MODIFIERS.normal)
	
	# Generate AI opponents
	for i in range(count):
		var ai_name = ai_names[i % ai_names.size()]
		var brand_model = _get_random_brand_model_filtered(exclude_brands)
		
		if brand_model.brand_id != "" and brand_model.model_id != "":
			var ai_croaker = _create_ai_croaker_from_data(ai_name, brand_model.brand_id, brand_model.model_id, diff_mod)
			if ai_croaker:
				ai_croakers.append(ai_croaker)
				continue
		
		# Fallback if specific creation failed
		print("[RaceManager] Fallback: Creating basic AI croaker %s" % ai_name)
		ai_croakers.append(_create_basic_ai_croaker(ai_name, diff_mod))
	
	print("[RaceManager] Generated %d AI opponents (difficulty: %s)" % [ai_croakers.size(), difficulty])
	return ai_croakers

func generate_challenge_ai(player_croaker_stats: Dictionary, difficulty: String) -> Array[Croaker]:
	"""
	Generate AI opponents specifically balanced against player stats for challenge races
	Returns array of challenge-tuned AI Croakers
	"""
	if not player_croaker_stats.has("jump_distance") or not player_croaker_stats.has("action_delay"):
		print("[RaceManager] ERROR: Invalid player stats for challenge AI generation")
		return []
	
	var challenge_ai: Array[Croaker] = []
	var diff_mod = AI_DIFFICULTY_MODIFIERS.get(difficulty, AI_DIFFICULTY_MODIFIERS.normal)
	
	# Create AI opponents with stats relative to player
	var base_jump = player_croaker_stats.jump_distance * diff_mod.stat_multiplier
	var base_delay = player_croaker_stats.action_delay / diff_mod.stat_multiplier
	var base_stamina = player_croaker_stats.get("stamina", 100.0) * diff_mod.stat_multiplier
	
	var challenge_names = ["Rival Racer", "Speed Challenger", "Elite Opponent"]
	
	for i in range(challenge_names.size()):
		var ai_croaker = _create_basic_ai_croaker(challenge_names[i], diff_mod)
		
		# Override stats to be competitive with player
		ai_croaker.jump_distance = base_jump * randf_range(0.95, 1.05)
		ai_croaker.action_delay = base_delay * randf_range(0.95, 1.05)
		ai_croaker.stamina = base_stamina * randf_range(0.95, 1.05)
		
		challenge_ai.append(ai_croaker)
	
	print("[RaceManager] Generated %d challenge AI opponents tuned to player stats" % challenge_ai.size())
	return challenge_ai

func _generate_fallback_ai_opponents(count: int, difficulty: String) -> Array[Croaker]:
	"""Generate basic AI croakers if GameManager data is unavailable"""
	var ai_croakers: Array[Croaker] = []
	var diff_mod = AI_DIFFICULTY_MODIFIERS.get(difficulty, AI_DIFFICULTY_MODIFIERS.normal)
	
	# Generate fallback names
	var fallback_names = []
	for i in range(count):
		fallback_names.append("AI Racer %d" % (i + 1))
	
	for ai_name in fallback_names:
		ai_croakers.append(_create_basic_ai_croaker(ai_name, diff_mod))
	
	print("[RaceManager] Generated %d fallback AI opponents" % ai_croakers.size())
	return ai_croakers

func _create_ai_croaker_from_data(croaker_name: String, brand_id: String, model_id: String, difficulty_mod: Dictionary) -> Croaker:
	"""Create an AI Croaker using GameManager data with difficulty modifiers"""
	if not GameManager or not GameManager.croaker_data.has("brands"):
		return null
	
	var brands = GameManager.croaker_data.brands
	if not brands.has(brand_id) or not brands[brand_id].has("models") or not brands[brand_id].models.has(model_id):
		return null
	
	var brand_data = brands[brand_id]
	var model_data = brand_data.models[model_id]
	var base_stats = model_data.base_stats
	
	# Create the Croaker
	var croaker = Croaker.new(croaker_name)
	
	# Apply base stats with difficulty modifiers and variance
	var stat_variance = GameManager.croaker_data.get("stat_variance", {})
	var variance_mod = difficulty_mod.stat_variance
	var stat_mult = difficulty_mod.stat_multiplier
	
	croaker.jump_distance = _apply_ai_stat_variance(base_stats.jump_distance * stat_mult, stat_variance.get("jump_distance", 0.0), variance_mod)
	croaker.action_delay = _apply_ai_stat_variance(base_stats.action_delay / stat_mult, stat_variance.get("action_delay", 0.0), variance_mod)
	croaker.stamina = _apply_ai_stat_variance(base_stats.stamina * stat_mult, stat_variance.get("stamina", 0.0), variance_mod)
	
	# Set brand and model info
	croaker.brand_id = brand_id
	croaker.model_id = model_id
	croaker.brand_name = brand_data.display_name
	croaker.model_name = model_data.display_name
	
	# Set visual properties
	croaker.color_primary = Color(model_data.get("color_primary", "#FFFFFF"))
	croaker.color_secondary = Color(model_data.get("color_secondary", "#000000"))
	croaker.size_modifier = model_data.get("size_modifier", 1.0)
	
	# Set personality based on difficulty preference
	var personality_pool = model_data.get("personality_pool", ["steady"])
	if difficulty_mod.personality_bias == "aggressive":
		# Prefer aggressive personalities
		var aggressive_personalities = personality_pool.filter(func(p): return p in ["aggressive", "sporty", "powerful"])
		if not aggressive_personalities.is_empty():
			personality_pool = aggressive_personalities
	elif difficulty_mod.personality_bias == "steady":
		# Prefer steady personalities
		var steady_personalities = personality_pool.filter(func(p): return p in ["steady", "reliable", "efficient"])
		if not steady_personalities.is_empty():
			personality_pool = steady_personalities
	
	croaker.personality = personality_pool[randi() % personality_pool.size()]
	
	return croaker

func _create_basic_ai_croaker(croaker_name: String, difficulty_mod: Dictionary) -> Croaker:
	"""Create a basic AI Croaker with difficulty-appropriate stats"""
	var croaker = Croaker.new(croaker_name)
	
	# Base stats modified by difficulty
	var stat_mult = difficulty_mod.stat_multiplier
	var variance = difficulty_mod.stat_variance
	
	croaker.jump_distance = _apply_ai_stat_variance(5.0 * stat_mult, 1.0, variance)
	croaker.action_delay = _apply_ai_stat_variance(1.0 / stat_mult, 0.2, variance)
	croaker.stamina = _apply_ai_stat_variance(100.0 * stat_mult, 20.0, variance)
	
	# Basic visual properties
	croaker.brand_name = "AI Racing"
	croaker.model_name = "Bot"
	croaker.color_primary = Color(randf(), randf(), randf())
	croaker.color_secondary = Color(randf(), randf(), randf())
	
	# Set personality based on difficulty
	var personalities = ["steady", "aggressive", "efficient"]
	if difficulty_mod.personality_bias == "aggressive":
		croaker.personality = "aggressive"
	elif difficulty_mod.personality_bias == "steady":
		croaker.personality = "steady"
	else:
		croaker.personality = personalities[randi() % personalities.size()]
	
	return croaker

func _apply_ai_stat_variance(base_value: float, base_variance: float, variance_modifier: float) -> float:
	"""Apply variance to AI stats with difficulty-based variance scaling"""
	var total_variance = base_variance * variance_modifier
	if total_variance <= 0.0:
		return base_value
	
	var min_val = base_value - total_variance
	var max_val = base_value + total_variance
	return randf_range(min_val, max_val)

func _get_random_brand_model_filtered(exclude_brands: Array) -> Dictionary:
	"""Get a random brand and model combination, excluding specified brands"""
	if not GameManager or not GameManager.croaker_data.has("brands"):
		return {"brand_id": "", "model_id": ""}
	
	var brands = GameManager.croaker_data.brands
	if brands.is_empty():
		return {"brand_id": "", "model_id": ""}
	
	# Filter out excluded brands
	var available_brands = []
	for brand_id in brands.keys():
		if not brand_id in exclude_brands:
			available_brands.append(brand_id)
	
	if available_brands.is_empty():
		# If all brands excluded, use any brand
		available_brands = brands.keys()
	
	var random_brand_id = available_brands[randi() % available_brands.size()]
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
# RACE CONFIGURATION
# =============================

func get_default_race_config(race_type: String) -> Dictionary:
	"""Get default configuration for a race type"""
	if race_type in DEFAULT_CONFIGS:
		return DEFAULT_CONFIGS[race_type].duplicate()
	else:
		print("[RaceManager] WARNING: Unknown race type '%s', returning run_race config" % race_type)
		return DEFAULT_CONFIGS["run_race"].duplicate()

func validate_race_config(config: Dictionary) -> bool:
	"""Validate a race configuration dictionary"""
	# Check required fields
	var required_fields = ["max_racers", "track_length", "ai_difficulty"]
	for field in required_fields:
		if not config.has(field):
			print("[RaceManager] ERROR: Missing required config field: %s" % field)
			return false
	
	# Validate field values
	if config.max_racers < 2 or config.max_racers > 16:
		print("[RaceManager] ERROR: Invalid max_racers: %d (must be 2-16)" % config.max_racers)
		return false
	
	if config.track_length <= 0:
		print("[RaceManager] ERROR: Invalid track_length: %f (must be > 0)" % config.track_length)
		return false
	
	if not config.ai_difficulty in AI_DIFFICULTY_MODIFIERS:
		print("[RaceManager] ERROR: Invalid ai_difficulty: %s" % config.ai_difficulty)
		return false
	
	return true

# =============================
# UTILITY METHODS
# =============================

func get_current_race_info() -> Dictionary:
	"""Get comprehensive information about the current race"""
	return {
		"race_type": current_race_type,
		"race_config": current_race_config.duplicate(),
		"racer_count": current_racers.size(),
		"race_active": race_in_progress,
		"player_croaker": current_racers[0] if not current_racers.is_empty() else null
	}

func get_race_stats() -> Dictionary:
	"""Get statistics from the last completed race"""
	if last_race_results.is_empty():
		return {}
	
	return {
		"total_racers": last_race_results.size(),
		"player_position": last_race_player_position,
		"winner": get_race_winner(),
		"player_won": last_race_player_position == 1,
		"player_podium": last_race_player_position <= 3
	}

# =============================
# DEBUG METHODS
# =============================

func debug_print_race_setup() -> void:
	"""Debug output for race setup"""
	print("[RaceManager] === RACE SETUP DEBUG ===")
	print("Race Type: %s" % current_race_type)
	print("Configuration: %s" % current_race_config)
	print("Racers (%d):" % current_racers.size())
	
	for i in range(current_racers.size()):
		var croaker = current_racers[i]
		var role = "PLAYER" if i == 0 else "AI"
		print("  %d. %s (%s) - %s %s | Jump: %.1f, Delay: %.1f, Personality: %s" % [
			i + 1, croaker.name, role, croaker.get_brand_name(), croaker.get_model_name(),
			croaker.jump_distance, croaker.action_delay, croaker.personality
		])
	print("===============================")

func debug_print_race_results() -> void:
	"""Debug output for race results"""
	if last_race_results.is_empty():
		print("[RaceManager] No race results to display")
		return
	
	print("[RaceManager] === RACE RESULTS DEBUG ===")
	print("Race Type: %s | Player Position: %d/%d" % [
		current_race_type, last_race_player_position, last_race_results.size()
	])
	
	for i in range(last_race_results.size()):
		var croaker = last_race_results[i]
		var player_indicator = " ★ (PLAYER)" if i + 1 == last_race_player_position else ""
		print("  %d. %s%s (%s %s) - Jump: %.1f, Delay: %.1f" % [
			i + 1, croaker.name, player_indicator, croaker.get_brand_name(), croaker.get_model_name(),
			croaker.jump_distance, croaker.action_delay
		])
	print("=================================")

func debug_print_all() -> void:
	"""Print all debug information"""
	if is_race_active():
		debug_print_race_setup()
	else:
		debug_print_race_results()
	
	var race_info = get_current_race_info()
	print("[RaceManager] === CURRENT STATE ===")
	print("Race Active: %s" % race_info.race_active)
	print("Race Type: %s" % race_info.race_type)
	print("Racer Count: %d" % race_info.racer_count)
	print("===============================")
