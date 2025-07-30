# croaker.gd - Racing entity Resource
# Represents a bio-mechanical car frog that can race and be upgraded
extends Resource
class_name Croaker

# Core Stats - exported for editor visibility and save/load
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
