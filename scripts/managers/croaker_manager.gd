# CroakerManager.gd - AutoLoad Singleton
# Manages the player's Croaker roster and collection
extends Node

signal croaker_added(croaker: Croaker)
signal croaker_removed(croaker_id: String)
signal roster_updated

# Debug flag for development
const DEBUG_CROAKER_MANAGER := true

# Data structures
var owned_croakers: Dictionary = {}  # String ID -> Croaker
var current_run_roster: Array[Croaker] = []  # Active Croakers for current run
var croaker_counter: int = 0  # For generating unique IDs

# Roster limits
const MAX_OWNED_CROAKERS := 50  # Prevent infinite collection
const MAX_RUN_ROSTER := 1  # Only 1 Croaker per run for MVP

# === CORE ROSTER MANAGEMENT ===

func add_croaker(croaker: Croaker) -> bool:
	"""Add a Croaker to the owned collection"""
	if owned_croakers.size() >= MAX_OWNED_CROAKERS:
		_debug_log("Cannot add Croaker - roster full (%d/%d)" % [owned_croakers.size(), MAX_OWNED_CROAKERS])
		return false
	
	# Generate unique ID if not set
	if croaker.id.is_empty():
		croaker.id = _generate_croaker_id()
	
	# Prevent duplicate IDs
	if owned_croakers.has(croaker.id):
		_debug_log("Croaker ID collision: %s" % croaker.id)
		croaker.id = _generate_croaker_id()
	
	owned_croakers[croaker.id] = croaker
	croaker_added.emit(croaker)
	roster_updated.emit()
	
	_debug_log("Added Croaker: %s (%s)" % [croaker.croaker_name, croaker.id])
	return true

func remove_croaker(croaker_id: String) -> bool:
	"""Remove a Croaker from the owned collection"""
	if not owned_croakers.has(croaker_id):
		_debug_log("Cannot remove Croaker - ID not found: %s" % croaker_id)
		return false
	
	var croaker = owned_croakers[croaker_id]
	owned_croakers.erase(croaker_id)
	
	# Remove from current run roster if present
	var run_index = current_run_roster.find(croaker)
	if run_index != -1:
		current_run_roster.remove_at(run_index)
	
	croaker_removed.emit(croaker_id)
	roster_updated.emit()
	
	_debug_log("Removed Croaker: %s (%s)" % [croaker.croaker_name, croaker_id])
	return true

func get_croaker(croaker_id: String) -> Croaker:
	"""Get a Croaker by ID"""
	return owned_croakers.get(croaker_id, null)

func get_all_croakers() -> Array[Croaker]:
	"""Get all owned Croakers as array"""
	var croakers: Array[Croaker] = []
	for croaker in owned_croakers.values():
		croakers.append(croaker)
	return croakers

func get_croaker_count() -> int:
	"""Get total number of owned Croakers"""
	return owned_croakers.size()

# === RUN ROSTER MANAGEMENT ===

func set_run_croaker(croaker: Croaker) -> bool:
	"""Set the active Croaker for current run (MVP: only 1 allowed)"""
	if not owned_croakers.has(croaker.id):
		_debug_log("Cannot set run Croaker - not owned: %s" % croaker.id)
		return false
	
	current_run_roster.clear()
	current_run_roster.append(croaker)
	
	_debug_log("Set run Croaker: %s" % croaker.croaker_name)
	return true

func get_run_croaker() -> Croaker:
	"""Get the active Croaker for current run"""
	if current_run_roster.is_empty():
		return null
	return current_run_roster[0]

func clear_run_roster() -> void:
	"""Clear the current run roster"""
	current_run_roster.clear()
	_debug_log("Cleared run roster")

func has_run_croaker() -> bool:
	"""Check if a Croaker is selected for current run"""
	return not current_run_roster.is_empty()

# === CROAKER QUERIES ===

func get_croakers_by_type(croaker_type: String) -> Array[Croaker]:
	"""Get all Croakers of a specific type"""
	var filtered: Array[Croaker] = []
	for croaker in owned_croakers.values():
		if croaker.croaker_type == croaker_type:
			filtered.append(croaker)
	return filtered

func get_croakers_by_wins(min_wins: int = 1) -> Array[Croaker]:
	"""Get Croakers with at least X wins (champions)"""
	var champions: Array[Croaker] = []
	for croaker in owned_croakers.values():
		if croaker.total_wins >= min_wins:
			champions.append(croaker)
	return champions

func get_strongest_croaker() -> Croaker:
	"""Get the Croaker with highest total stats"""
	var strongest: Croaker = null
	var highest_power := 0.0
	
	for croaker in owned_croakers.values():
		var power = croaker.stats.get_total_power()
		if power > highest_power:
			highest_power = power
			strongest = croaker
	
	return strongest

# === SAVE/LOAD PREPARATION ===

func get_save_data() -> Dictionary:
	"""Prepare Croaker roster data for saving"""
	var save_data = {
		"owned_croakers_count": owned_croakers.size(),
		"croaker_counter": croaker_counter,
		"current_run_croaker_id": "",
		"croakers": []
	}
	
	# Store current run Croaker ID
	if has_run_croaker():
		save_data.current_run_croaker_id = get_run_croaker().id
	
	# Serialize all owned Croakers
	for croaker in owned_croakers.values():
		save_data.croakers.append(croaker.to_dict())
	
	_debug_log("Prepared save data for %d Croakers" % owned_croakers.size())
	return save_data

func load_save_data(save_data: Dictionary) -> bool:
	"""Load Croaker roster from save data"""
	if not save_data.has("croakers"):
		_debug_log("Invalid save data - missing croakers array")
		return false
	
	# Clear current data
	owned_croakers.clear()
	current_run_roster.clear()
	
	# Restore counter
	croaker_counter = save_data.get("croaker_counter", 0)
	
	# Load Croakers
	var loaded_count = 0
	for croaker_data in save_data.croakers:
		var croaker = Croaker.new()
		if croaker.from_dict(croaker_data):
			owned_croakers[croaker.id] = croaker
			loaded_count += 1
		else:
			_debug_log("Failed to load Croaker data: %s" % str(croaker_data))
	
	# Restore current run Croaker
	var run_croaker_id = save_data.get("current_run_croaker_id", "")
	if not run_croaker_id.is_empty() and owned_croakers.has(run_croaker_id):
		current_run_roster.append(owned_croakers[run_croaker_id])
	
	roster_updated.emit()
	_debug_log("Loaded %d Croakers from save data" % loaded_count)
	return true

# === DEBUG METHODS ===

func generate_test_croakers(count: int = 3) -> void:
	"""Generate test Croakers for development"""
	var test_types = ["Speed Demon", "Heavy Jumper", "Balanced", "Lucky"]
	var test_names = ["Hopscotch", "Ribbert", "Lily", "Croaksworth", "Puddles", "Splash", "Bounce", "Slippy"]
	
	for i in range(count):
		var croaker = Croaker.new()
		
		# Random name and type
		croaker.croaker_name = test_names[randi() % test_names.size()] + " " + str(i + 1)
		croaker.croaker_type = test_types[randi() % test_types.size()]
		
		# Generate varied stats for testing
		croaker.stats.jump_distance = randf_range(8.0, 15.0)
		croaker.stats.action_delay = randf_range(0.8, 1.5)
		croaker.stats.stamina = randf_range(80.0, 120.0)
		
		# Some test Croakers have wins
		if randf() < 0.3:
			croaker.total_wins = randi_range(1, 5)
			croaker.total_races = croaker.total_wins + randi_range(2, 8)
		
		add_croaker(croaker)
	
	_debug_log("Generated %d test Croakers" % count)

func print_roster_status() -> void:
	"""Debug method to print current roster state"""
	print("\n=== CROAKER ROSTER STATUS ===")
	print("Owned Croakers: %d/%d" % [owned_croakers.size(), MAX_OWNED_CROAKERS])
	print("Run Croaker: %s" % (get_run_croaker().croaker_name if has_run_croaker() else "None"))
	
	if owned_croakers.size() > 0:
		print("\nOwned Croakers:")
		for croaker in owned_croakers.values():
			var power = croaker.stats.get_total_power()
			print("  %s (%s) - Power: %.1f - Wins: %d" % [croaker.croaker_name, croaker.croaker_type, power, croaker.total_wins])
	
	print("===============================\n")

func clear_all_croakers() -> void:
	"""Debug method to clear all Croakers"""
	owned_croakers.clear()
	current_run_roster.clear()
	croaker_counter = 0
	roster_updated.emit()
	_debug_log("Cleared all Croakers")

# === PRIVATE METHODS ===

func _generate_croaker_id() -> String:
	"""Generate unique Croaker ID"""
	croaker_counter += 1
	return "croaker_%d" % croaker_counter

func _debug_log(message: String) -> void:
	"""Debug logging helper"""
	if DEBUG_CROAKER_MANAGER:
		print("[CROAKER-MGR] %s" % message)

# === INITIALIZATION ===

func _ready() -> void:
	"""Initialize the CroakerManager"""
	_debug_log("CroakerManager initialized")
	
	# Generate some test Croakers for development
	if DEBUG_CROAKER_MANAGER and owned_croakers.is_empty():
		generate_test_croakers(3)
		
		# Set first Croaker as run Croaker for testing
		if owned_croakers.size() > 0:
			var first_croaker = owned_croakers.values()[0]
			set_run_croaker(first_croaker)
