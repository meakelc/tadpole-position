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
	"""Get all racers for a race (active croakers only - excludes eliminated)"""
	var lineup: Array[Croaker] = []
	
	if not RunManager:
		print("[RaceManager] ERROR: RunManager not available for race lineup")
		return lineup
	
	# Get only active croakers (not eliminated)
	lineup = RunManager.get_active_croakers()
	
	# Validate lineup size based on current race number
	var expected_count = _get_expected_croaker_count()
	if lineup.size() != expected_count:
		print("[RaceManager] WARNING: Lineup size mismatch - Expected: %d, Got: %d" % [expected_count, lineup.size()])
		
		# Additional debug info
		var elimination_summary = RunManager.get_elimination_summary()
		print("[RaceManager] Tournament Status: %d active, %d eliminated (of %d total)" % [
			elimination_summary.active_count,
			elimination_summary.eliminated_count, 
			elimination_summary.total_croakers
		])
	
	print("[RaceManager] Race lineup prepared: %d active racers (Race #%d)" % [
		lineup.size(), 
		RunManager.get_current_race_number()
	])
	
	return lineup

func _get_expected_croaker_count() -> int:
	"""Get expected number of croakers based on current race number and eliminations"""
	if not RunManager:
		return 0
	
	var race_number = RunManager.get_current_race_number()
	
	# Tournament progression: 16 → 12 → 8 → 4
	if race_number <= 3:
		return 16  # Races 1-3: All initial croakers
	elif race_number <= 6:
		return 12  # Races 4-6: After first elimination 
	elif race_number <= 9:
		return 8   # Races 7-9: After second elimination
	else:
		return 4   # Races 10+: After third elimination (final 4)

# =============================
# RACE RESULTS MANAGEMENT
# =============================

func store_race_results(results: Array[Croaker]) -> void:
	"""Store race results and notify RunManager"""
	if results.is_empty():
		print("[RaceManager] ERROR: Cannot store empty race results")
		return
	
	# Store current race results
	last_race_results = results.duplicate()
	
	# Find and store player position
	if not RunManager or not RunManager.current_croaker:
		print("[RaceManager] ERROR: No current croaker available to find position")
		last_race_position = results.size()  # Assume last place
	else:
		last_race_position = results.find(RunManager.current_croaker) + 1
		if last_race_position == 0:  # Player not found in results
			print("[RaceManager] WARNING: Player not found in race results")
			last_race_position = results.size()  # Assume last place
	
	print("[RaceManager] Stored race results - Player finished %d/%d" % [
		last_race_position, results.size()
	])
	
	# REMOVED: handle_elimination_race() call - let RunManager handle ALL elimination logic
	
	# Notify RunManager to update its race tracking and handle eliminations
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
# HELPER METHODS (For Reference Only)
# =============================

func _get_elimination_count_for_race(race_number: int) -> int:
	"""Get number of croakers to eliminate for a specific race"""
	match race_number:
		3: return 4   # Race 3: 16 → 12 (eliminate 4)
		6: return 4   # Race 6: 12 → 8  (eliminate 4)  
		9: return 4   # Race 9: 8 → 4   (eliminate 4)
		_: return 0   # No eliminations for other races

func _get_expected_croaker_count_after_elimination(race_number: int) -> int:
	"""Get expected croaker count after elimination for specific race"""
	match race_number:
		3: return 12  # After race 3 elimination
		6: return 8   # After race 6 elimination
		9: return 4   # After race 9 elimination
		_: return _get_expected_croaker_count()  # No change for non-elimination races

# =============================
# DEBUG METHODS
# =============================

func debug_print_race_results() -> void:
	"""Debug function to print last race results with elimination context"""
	if last_race_results.is_empty():
		print("[RaceManager] No race results to display")
		return
	
	var current_race_number = RunManager.get_current_race_number() - 1  # Subtract 1 because race is complete
	var was_elimination = (current_race_number % 3 == 0)
	
	print("[RaceManager] === LAST RACE RESULTS ===")
	print("Race #%d | Player Position: %d/%d | %s" % [
		current_race_number, 
		last_race_position, 
		last_race_results.size(),
		"ELIMINATION RACE" if was_elimination else "Regular Race"
	])
	
	# Show field reduction context
	if RunManager:
		var elimination_summary = RunManager.get_elimination_summary()
		print("Field Status: %d active, %d eliminated" % [
			elimination_summary.active_count,
			elimination_summary.eliminated_count
		])
	
	for i in range(last_race_results.size()):
		var croaker = last_race_results[i]
		var player_indicator = " ★ (PLAYER)" if RunManager and croaker == RunManager.current_croaker else ""
		var elimination_indicator = ""
		
		# Mark eliminated racers in elimination races
		if was_elimination and RunManager:
			var elimination_count = _get_elimination_count_for_race(current_race_number)
			if elimination_count > 0 and i >= (last_race_results.size() - elimination_count):
				elimination_indicator = " [ELIMINATED]"
		
		print("  %d. %s%s%s (%s %s) - Jump: %.1f, Delay: %.1f" % [
			i + 1,
			croaker.name,
			player_indicator,
			elimination_indicator,
			croaker.get_brand_name(),
			croaker.get_model_name(),
			croaker.jump_distance,
			croaker.action_delay
		])
	print("===================================")

func debug_print_race_state() -> void:
	"""Debug function to print race-related state with elimination tracking"""
	print("[RaceManager] === RACE STATE DEBUG ===")
	print("Current Race: #%d (%s)" % [
		RunManager.get_current_race_number(),
		"ELIMINATION" if RunManager.is_next_race_elimination() else "Regular"
	])
	print("Races Until Elimination: %d" % RunManager.get_races_until_elimination())
	print("Last Race Position: %d" % last_race_position)
	print("Results Available: %s" % ("Yes" if not last_race_results.is_empty() else "No"))
	
	# Enhanced field status
	if RunManager:
		var elimination_summary = RunManager.get_elimination_summary()
		var expected_count = _get_expected_croaker_count()
		
		print("Expected Field Size: %d croakers" % expected_count)
		print("Actual Field Size: %d active croakers" % elimination_summary.active_count)
		print("Total Eliminated: %d croakers" % elimination_summary.eliminated_count)
		print("Player Status: %s" % ("ACTIVE" if elimination_summary.player_active else "ELIMINATED"))
		
		if elimination_summary.active_count != expected_count:
			print("⚠️  WARNING: Field size mismatch detected!")
	
	print("==================================")

func debug_print_tournament_bracket() -> void:
	"""Debug function to show tournament elimination bracket status"""
	if not RunManager:
		print("[RaceManager] RunManager not available for bracket status")
		return
	
	print("[RaceManager] === TOURNAMENT BRACKET ===")
	
	var race_number = RunManager.get_current_race_number()
	var elimination_summary = RunManager.get_elimination_summary()
	
	# Show tournament progression
	var stages = [
		{"name": "Initial Field", "races": "1-3", "count": 16, "status": ""},
		{"name": "Round of 12", "races": "4-6", "count": 12, "status": ""},
		{"name": "Round of 8", "races": "7-9", "count": 8, "status": ""},
		{"name": "Final 4", "races": "10+", "count": 4, "status": ""}
	]
	
	for i in range(stages.size()):
		var stage = stages[i]
		var is_current = false
		var is_complete = false
		
		# Determine current stage
		if race_number <= 3 and i == 0:
			is_current = true
		elif race_number >= 4 and race_number <= 6 and i == 1:
			is_current = true
		elif race_number >= 7 and race_number <= 9 and i == 2:
			is_current = true
		elif race_number >= 10 and i == 3:
			is_current = true
		
		# Determine completed stages
		if (race_number > 3 and i == 0) or (race_number > 6 and i == 1) or (race_number > 9 and i == 2):
			is_complete = true
		
		# Set status indicators
		if is_current:
			stage.status = " ← CURRENT"
		elif is_complete:
			stage.status = " ✓ COMPLETE"
		else:
			stage.status = " (upcoming)"
		
		print("  %s (Races %s): %d racers%s" % [stage.name, stage.races, stage.count, stage.status])
	
	print("Current Status: %d active, %d eliminated" % [
		elimination_summary.active_count,
		elimination_summary.eliminated_count
	])
	print("=========================================")
