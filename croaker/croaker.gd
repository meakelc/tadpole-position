# croaker.gd - Racing entity Resource
# Represents a bio-mechanical car frog that can race and be upgraded
extends Resource
class_name Croaker

# Core Stats - exported for editor visibility and save/load
@export_group("Stats")
@export var jump_distance: float = 5.0  # How far each jump travels
@export var action_delay: float = 1.0   # Cooldown between jumps in seconds
@export var stamina: float = 100.0      # Optional stat for future features

# Identity and Progression
@export var name: String = ""
@export var upgrades_equipped: Array[int] = []       # Array of upgrade IDs applied
@export var warts_equipped: Array = []      # Wart resources (skills/badges)

# Brand and Model Information (from croakers.json)
@export_group("Brand/Model")
@export var brand_id: String = ""           # e.g., "toytoada"
@export var model_id: String = ""           # e.g., "coroalla"
@export var brand_name: String = ""         # e.g., "Toytoada"
@export var model_name: String = ""         # e.g., "Coroalla"

# Visual Properties
@export_group("Appearance")
@export var color_primary: Color = Color.WHITE
@export var color_secondary: Color = Color.BLACK
@export var size_modifier: float = 1.0      # Visual size scaling
@export var personality: String = "steady"  # AI behavior type

func _init(croaker_name: String = "") -> void:
	name = croaker_name
	
	print("[Croaker] Created: '%s' - Jump: %.1f, Delay: %.1f" % [croaker_name, jump_distance, action_delay])

# Get brand name for display
func get_brand_name() -> String:
	return brand_name if brand_name != "" else "Unknown"

# Get model name for display  
func get_model_name() -> String:
	return model_name if model_name != "" else "Model"

# Get full type name (brand + model)
func get_full_type_name() -> String:
	return "%s %s" % [get_brand_name(), get_model_name()]

# Get short type identifier
func get_type_id() -> String:
	return "%s_%s" % [brand_id, model_id] if brand_id != "" and model_id != "" else "unknown"

# =============================
# UPGRADE METHODS
# =============================

func apply_upgrade(upgrade_type: String, value: float) -> bool:
	"""
	Apply an upgrade to this Croaker's stats
	Returns true if successful, false if failed
	"""
	match upgrade_type:
		"jump_distance":
			jump_distance += value
			jump_distance = max(0.1, jump_distance)  # Min cap
			print("[Croaker] '%s' applied jump upgrade: %+.1f (new total: %.1f)" % [
				name, value, jump_distance
			])
			return true
			
		"action_delay":
			action_delay += value  # Negative values make it faster
			action_delay = max(0.1, action_delay)  # Min cap
			print("[Croaker] '%s' applied speed upgrade: %+.1f (new delay: %.1f)" % [
				name, value, action_delay
			])
			return true
			
		"stamina":
			stamina += value
			stamina = max(1.0, stamina)  # Min cap
			print("[Croaker] '%s' applied stamina upgrade: %+.1f (new total: %.1f)" % [
				name, value, stamina
			])
			return true
			
		_:
			print("[Croaker] ERROR: '%s' unknown upgrade type: %s" % [name, upgrade_type])
			return false

func can_apply_upgrade(upgrade_type: String, value: float) -> bool:
	"""
	Check if an upgrade can be applied without breaking stat limits
	Returns true if upgrade is valid, false otherwise
	"""
	match upgrade_type:
		"jump_distance":
			return (jump_distance + value) >= 0.1
		"action_delay":
			return (action_delay + value) >= 0.1
		"stamina":
			return (stamina + value) >= 1.0
		_:
			return false

func get_upgrade_preview(upgrade_type: String, value: float) -> Dictionary:
	"""
	Preview what an upgrade would do without applying it
	Returns dictionary with current, new, and change values
	"""
	var preview = {
		"valid": false,
		"current": 0.0,
		"new": 0.0,
		"change": value,
		"stat_name": ""
	}
	
	match upgrade_type:
		"jump_distance":
			preview.valid = can_apply_upgrade(upgrade_type, value)
			preview.current = jump_distance
			preview.new = max(0.1, jump_distance + value)
			preview.stat_name = "Jump Distance"
		"action_delay":
			preview.valid = can_apply_upgrade(upgrade_type, value)
			preview.current = action_delay
			preview.new = max(0.1, action_delay + value)
			preview.stat_name = "Action Delay"
		"stamina":
			preview.valid = can_apply_upgrade(upgrade_type, value)
			preview.current = stamina
			preview.new = max(1.0, stamina + value)
			preview.stat_name = "Stamina"
		_:
			preview.stat_name = "Unknown"
	
	return preview

# =============================
# RACE STATE
# =============================

# Runtime Racing State (not exported - reset each race)
var visual_node: Node = null
var position: float = 0.0              # Current race position
var action_cooldown: float = 0.0       # Current cooldown remaining

# Call at the start of every race
func reset_race_state() -> void:
	visual_node = null
	position = 0.0
	action_cooldown = 0.0
	print("[Croaker] Reset race state for '%s' (%s)" % [name, get_full_type_name()])

func set_visual_node(v_node: Node) -> void:
	visual_node = v_node

func update_race_state(delta: float) -> bool:
	action_cooldown -= delta
	if action_cooldown <= 0.0:
		perform_action()
		return true
	return false
	# Update race visual occurs in Run._race_tick

func perform_action() -> void:
	# Apply personality-based variance to jump performance
	var jump_variance = _get_personality_jump_variance()
	var delay_variance = _get_personality_delay_variance()
	
	position += jump_distance * jump_variance
	action_cooldown = action_delay * delay_variance

# Get jump distance variance based on personality
func _get_personality_jump_variance() -> float:
	match personality:
		"aggressive":
			return randf_range(0.7, 1.3)  # Higher variance, risk/reward
		"steady":
			return randf_range(0.9, 1.1)  # Consistent performance
		"efficient":
			return randf_range(0.85, 1.15) # Slightly better than steady
		"powerful":
			return randf_range(0.8, 1.2)   # Good variance with slight power bias
		"sporty":
			return randf_range(0.75, 1.25) # High variance like aggressive
		_:
			return randf_range(0.8, 1.2)   # Default variance

# Get action delay variance based on personality  
func _get_personality_delay_variance() -> float:
	match personality:
		"aggressive":
			return randf_range(0.8, 1.2)   # Can be fast or slow
		"steady":
			return randf_range(0.95, 1.05) # Very consistent timing
		"efficient":
			return randf_range(0.9, 1.0)   # Tends to be faster
		"powerful":
			return randf_range(1.0, 1.1)   # Slightly slower but consistent
		"sporty":
			return randf_range(0.85, 1.15) # Good variance
		_:
			return randf_range(0.9, 1.1)   # Default variance
