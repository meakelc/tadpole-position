# croaker.gd - Racing entity Resource with brand/model support
# Represents a bio-mechanical car frog that can race and be upgraded
extends Resource
class_name Croaker

# Core Stats - exported for editor visibility and save/load
@export_group("Stats")
@export var jump_distance: float = 5.0  # How far each jump travels
@export var action_delay: float = 1.0   # Cooldown between jumps in seconds
@export var stamina: float = 100.0      # Optional stat for future features

# Identity and Progression
@export_group("Identity")
@export var name: String = ""
@export var brand_id: String = ""       # e.g., "forg", "leep"
@export var model_id: String = ""       # e.g., "mustang", "wrangler"
@export var personality: String = ""    # Selected from personality_pool

# Visual Properties
@export_group("Visual")
@export var color_primary: Color = Color.WHITE
@export var color_secondary: Color = Color.BLACK
@export var size_modifier: float = 1.0

# Progression
@export var upgrades_equipped: Array[int] = []       # Array of upgrade IDs applied
@export var warts_equipped: Array = []               # Wart resources (skills/badges)

# Static data loaded from JSON
static var croaker_data: Dictionary = {}

# Load croaker data on first use
static func _static_init() -> void:
	_load_croaker_data()

static func _load_croaker_data() -> void:
	var file = FileAccess.open("res://data/croakers.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			croaker_data = json.data
			print("[Croaker] Loaded croaker data with %d brands" % croaker_data.brands.size())
		else:
			print("[Croaker] ERROR: Failed to parse croakers.json")
	else:
		print("[Croaker] ERROR: Could not open croakers.json")

# Create a new Croaker with specific brand/model
static func create_from_brand(brand_id: String, model_id: String, croaker_name: String = "") -> Croaker:
	var croaker = Croaker.new()
	
	# Validate brand and model exist
	if not croaker_data.brands.has(brand_id):
		print("[Croaker] ERROR: Unknown brand '%s'" % brand_id)
		return croaker
	
	var brand_data = croaker_data.brands[brand_id]
	if not brand_data.models.has(model_id):
		print("[Croaker] ERROR: Unknown model '%s' for brand '%s'" % [model_id, brand_id])
		return croaker
	
	var model_data = brand_data.models[model_id]
	
	# Set identity
	croaker.brand_id = brand_id
	croaker.model_id = model_id
	
	# Generate name if not provided
	if croaker_name == "":
		croaker_name = _generate_croaker_name(brand_data.display_name, model_data.display_name)
	croaker.name = croaker_name
	
	# Set base stats with variance
	var variance = croaker_data.stat_variance
	croaker.jump_distance = model_data.base_stats.jump_distance + randf_range(-variance.jump_distance, variance.jump_distance)
	croaker.action_delay = model_data.base_stats.action_delay + randf_range(-variance.action_delay, variance.action_delay)
	croaker.stamina = model_data.base_stats.stamina + randf_range(-variance.stamina, variance.stamina)
	
	# Set visual properties
	croaker.color_primary = Color.from_string(model_data.color_primary, Color.WHITE)
	croaker.color_secondary = Color.from_string(model_data.color_secondary, Color.BLACK)
	croaker.size_modifier = model_data.size_modifier
	
	# Select personality
	var personalities = model_data.personality_pool
	croaker.personality = personalities[randi() % personalities.size()]
	
	print("[Croaker] Created %s %s: '%s' - Jump: %.1f, Delay: %.1f, Personality: %s" % [
		brand_data.display_name,
		model_data.display_name,
		croaker.name,
		croaker.jump_distance,
		croaker.action_delay,
		croaker.personality
	])
	
	return croaker

# Create a random Croaker from all available brand/model combinations
static func create_random() -> Croaker:
	# Build pool of all available brand/model combinations
	var pool = []
	
	for brand_id in croaker_data.brands:
		var brand = croaker_data.brands[brand_id]
		for model_id in brand.models:
			pool.append({"brand": brand_id, "model": model_id})
	
	# Select random from pool
	var selection = pool[randi() % pool.size()]
	return create_from_brand(selection.brand, selection.model)

# Generate a fun name for the Croaker
static func _generate_croaker_name(brand_name: String, model_name: String) -> String:
	var prefixes = ["Swift", "Lucky", "Mighty", "Thunder", "Lightning", "Turbo", "Super", "Ultra", "Mega", "Hyper"]
	var suffixes = ["Jr.", "III", "the Fast", "the Brave", "the Bold", "Champion", "Racer", "Speedster"]
	
	var prefix = prefixes[randi() % prefixes.size()]
	
	# Sometimes just use prefix + model
	if randf() < 0.5:
		return "%s %s" % [prefix, model_name]
	else:
		# Sometimes add a suffix too
		var suffix = suffixes[randi() % suffixes.size()]
		return "%s %s" % [prefix, suffix]

# Instance methods
func _init(croaker_name: String = "") -> void:
	name = croaker_name
	if croaker_name != "":
		print("[Croaker] Created generic croaker: '%s'" % croaker_name)

# Get display information
func get_brand_name() -> String:
	if brand_id == "" or not croaker_data.brands.has(brand_id):
		return "Generic"
	return croaker_data.brands[brand_id].display_name

func get_model_name() -> String:
	if brand_id == "" or model_id == "" or not croaker_data.brands.has(brand_id):
		return "Standard"
	var brand = croaker_data.brands[brand_id]
	if not brand.models.has(model_id):
		return "Standard"
	return brand.models[model_id].display_name

func get_full_type_name() -> String:
	return "%s %s" % [get_brand_name(), get_model_name()]

# =============================
# RACE STATE
# =============================

# Runtime Racing State (not exported - reset each race)
@export_group("Race State")
var visual_node: Node = null
var position: float = 0.0              # Current race position
var action_cooldown: float = 0.0       # Current cooldown remaining

# Call at the start of every race
func reset_race_state() -> void:
	visual_node = null
	position = 0.0
	action_cooldown = 0.0
	print("[Croaker] Reset race state for '%s'" % name)

func set_visual_node(v_node: Node) -> void:
	visual_node = v_node
	
	# Apply visual properties if it's a ColorRect
	if v_node is ColorRect:
		v_node.color = color_primary
		v_node.size = v_node.size * size_modifier

func update_race_state(delta: float) -> void:
	action_cooldown -= delta
	if action_cooldown <= 0.0:
		perform_action()

func perform_action() -> void:
	# Add personality-based variance
	var personality_modifier = 1.0
	match personality:
		"aggressive", "powerful":
			personality_modifier = randf_range(0.7, 1.3)  # High variance
		"steady", "reliable", "efficient":
			personality_modifier = randf_range(0.95, 1.05)  # Low variance
		"nimble", "agile", "lightweight":
			personality_modifier = randf_range(0.85, 1.15)  # Medium variance, slightly faster
		"technical", "precise":
			personality_modifier = randf_range(0.98, 1.02)  # Very low variance
		_:
			personality_modifier = randf_range(0.9, 1.1)  # Default variance
	
	position += jump_distance * personality_modifier
	action_cooldown = action_delay * randf_range(0.9, 1.1)
