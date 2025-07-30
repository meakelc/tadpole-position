# race.gd - Race scene script for race.tscn
extends Control

# UI elements (create these as child nodes in race.tscn)
@onready var racing_label: Label = $VBoxContainer/RacingLabel
@onready var track_container: Control = $VBoxContainer/TrackContainer
@onready var racer_1: ColorRect = $VBoxContainer/TrackContainer/Racer1
@onready var racer_2: ColorRect = $VBoxContainer/TrackContainer/Racer2
@onready var racer_3: ColorRect = $VBoxContainer/TrackContainer/Racer3
@onready var racer_4: ColorRect = $VBoxContainer/TrackContainer/Racer4
@onready var back_button: Button = $VBoxContainer/BackButton

# Racing state
var racers: Array[ColorRect] = []
var croakers: Array[Croaker] = []

# Track settings
const TRACK_WIDTH := 800
const RACER_SIZE := Vector2(40, 30)
const LANE_HEIGHT := 50

func _ready() -> void:
	print("[Race] Race scene ready")
	
	# Set up UI elements
	racing_label.text = "Racing..."
	back_button.text = "Back to Training"
	
	# Initialize racers array
	racers = [racer_1, racer_2, racer_3, racer_4]
	
	# Position and style racers
	_setup_racers()
	
	# Create test Croakers
	_create_test_croakers()
	
	# Connect back button
	back_button.pressed.connect(_on_back_pressed)
	
	print("[Race] 4 racers positioned and ready")

func _setup_racers() -> void:
	# Set up track container size
	track_container.custom_minimum_size = Vector2(TRACK_WIDTH, LANE_HEIGHT * 4)
	
	# Colors for each racer
	var racer_colors: Array[Color] = [
		Color.GREEN,   # Player Croaker
		Color.RED,     # AI Opponent 1
		Color.BLUE,    # AI Opponent 2
		Color.YELLOW   # AI Opponent 3
	]
	
	# Position each racer in their lane
	for i in range(4):
		var racer = racers[i]
		
		# Set color and size
		racer.color = racer_colors[i]
		racer.size = RACER_SIZE
		
		# Position at start of their lane
		var lane_y = i * LANE_HEIGHT + (LANE_HEIGHT - RACER_SIZE.y) / 2
		racer.position = Vector2(10, lane_y)
		
		print("[Race] Racer %d positioned at (%.1f, %.1f) with color %s" % [
			i + 1, racer.position.x, racer.position.y, racer_colors[i]
		])

func _create_test_croakers() -> void:
	# Create test Croakers with different stats
	var croaker_data = [
		{"name": "Player Frog", "jump": 6.0, "delay": 0.9},
		{"name": "Speedy AI", "jump": 5.5, "delay": 0.8},
		{"name": "Jumpy AI", "jump": 7.0, "delay": 1.2},
		{"name": "Steady AI", "jump": 5.8, "delay": 1.0}
	]
	
	for i in range(4):
		var data = croaker_data[i]
		var croaker = Croaker.new(data.name)
		croaker.jump_distance = data.jump
		croaker.action_delay = data.delay
		croaker.set_visual_node(racers[i])
		croakers.append(croaker)
		
		print("[Race] Created Croaker: %s (Jump: %.1f, Delay: %.1f)" % [
			croaker.name, croaker.jump_distance, croaker.action_delay
		])

func _on_back_pressed() -> void:
	print("[Race] Back button pressed - returning to training")
	GameManager.change_scene("res://scenes/game_flow/training.tscn")
