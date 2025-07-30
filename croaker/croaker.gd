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

func _init(croaker_name: String = "") -> void:
	name = croaker_name
	
	print("[Croaker] Created: '%s' - Jump: %.1f, Delay: %.1f" % [croaker_name, jump_distance, action_delay])
	
# =============================
# RACE STATE
# =============================

# Runtime Racing State (not exported - reset each race)
@export_group("Race State")
var position: float = 0.0              # Current race position
var action_cooldown: float = 0.0       # Current cooldown remaining

# Call at the start of every race
func reset_race_state() -> void:
	position = 0.0
	action_cooldown = 0.0
	print("[Croaker] Reset race state for '%s'" % name)

func update_race_state(delta: float) -> void:
	action_cooldown = max(0.0, action_cooldown - delta)

func perform_action() -> void:
	position += jump_distance * randf_range(0.8, 1.2)
	action_cooldown = action_delay * randf_range(0.8, 1.2)
