# race_manager.gd - AutoLoad Singleton for Race Management
# Handles race-specific state, results, and lineup management
extends Node

# =============================
# RACE STATE
# =============================

# Race results storage
var last_race_results: Array[Croaker] = []  # All racers in finishing order
var last_race_position: int = 0  # Player's finishing position

# =============================
# RACE LIFECYCLE
# =============================

func _ready() -> void:
	print("[RaceManager] RaceManager singleton initialized")
	_validate_dependencies()

func _validate_dependencies() -> void:
	"""Ensure required managers are available"""
	if not GameManager:
		print("[RaceManager] ERROR: GameManager not found! Ensure it's loaded as AutoLoad before RaceManager")
	if not RunManager:
		print("[RaceManager] ERROR: RunManager not found! Ensure it's loaded as AutoLoad before RaceManager")

# =============================
# RACE LINEUP MANAGEMENT
# =============================

func get_race_lineup() -> Array[Croaker]:
	"""Get all racers for a race (player + AI)"""
	var lineup: Array[Croaker] = []
	
	if not RunManager:
		print("[RaceManager] ERROR: RunManager not available for race lineup")
		return lineup
	
	if RunManager.current_croaker:
		lineup.append(RunManager.current_croaker)
	
	lineup.append_array(RunManager.ai_croakers)
	
	print("[RaceManager] Race lineup prepared: %d racers" % lineup.size())
	return lineup

# =============================
# RACE RESULTS MANAGEMENT
# =============================

func store_race_results(results: Array[Croaker]) -> void:
	"""Store race results and update related state"""
	if results.is_empty():
		print("[RaceManager] ERROR: Cannot store empty race results")
		return
	
	# Store current race results
	last_race_results = results.duplicate()
	
	# Find and store player position
	if not RunManager or not RunManager.current_croaker:
		print("[RaceManager] ERROR: No current croaker available to find position")
		last_race_position = results.size()  # Assume last place
		return
	
	last_race_position = results.find(RunManager.current_croaker) + 1
	if last_race_position == 0:  # Player not found in results
		print("[RaceManager] WARNING: Player not found in race results")
		last_race_position = results.size()  # Assume last place
	
	print("[RaceManager] Stored race results - Player finished %d/%d" % [
		last_race_position, results.size()
	])
	
	# Notify RunManager to update its race tracking
	if RunManager:
		RunManager._on_race_completed(results, last_race_position)

func clear_race_results() -> void:
	"""Clear race results data"""
	last_race_results.clear()
	last_race_position = 0
	print("[RaceManager] Race results cleared")

func get_last_race_player_position() -> int:
	"""Get player's position in the last race (1-indexed)"""
	return last_race_position

# =============================
# DEBUG METHODS
# =============================

func debug_print_race_results() -> void:
	"""Debug function to print last race results"""
	if last_race_results.is_empty():
		print("[RaceManager] No race results to display")
		return
	
	var current_race_number = RunManager.get_current_race_number() - 1  # Subtract 1 because race is complete
	print("[RaceManager] === LAST RACE RESULTS ===")
	print("Race #%d | Player Position: %d/%d" % [current_race_number, last_race_position, last_race_results.size()])
	
	for i in range(last_race_results.size()):
		var croaker = last_race_results[i]
		var player_indicator = " ★ (PLAYER)" if RunManager and croaker == RunManager.current_croaker else ""
		print("  %d. %s%s (%s %s) - Jump: %.1f, Delay: %.1f" % [
			i + 1,
			croaker.name,
			player_indicator,
			croaker.get_brand_name(),
			croaker.get_model_name(),
			croaker.jump_distance,
			croaker.action_delay
		])
	print("===================================")

func debug_print_race_state() -> void:
	"""Debug function to print race-related state"""
	print("[RaceManager] === RACE STATE DEBUG ===")
	print("Current Race: #%d (%s)" % [
		RunManager.get_current_race_number(),
		"ELIMINATION" if RunManager.is_next_race_elimination() else "Regular"
	])
	print("Races Until Elimination: %d" % RunManager.get_races_until_elimination())
	print("Last Race Position: %d" % last_race_position)
	print("Results Available: %s" % ("Yes" if not last_race_results.is_empty() else "No"))
	print("==================================")
