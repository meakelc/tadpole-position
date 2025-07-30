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
const FINISH_LINE := TRACK_WIDTH - 20  # Leave some space before the edge

# Race state
var race_active := false
var race_finished := false

func _ready() -> void:
	print("[Race] Race scene ready")
	
	# Set up UI elements
	racing_label.text = "Get Ready..."
	back_button.text = "Back to Training"
	
	# Initialize racers array
	racers = [racer_1, racer_2, racer_3, racer_4]
	
	# Position and style racers
	_setup_racers()
	
	# Create test Croakers
	_create_test_croakers()
	
	# Connect back button
	back_button.pressed.connect(_on_back_pressed)
	
	# Start race after a brief delay
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_start_race)
	add_child(timer)
	timer.start()
	
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
		croaker.reset_race_state()  # Initialize race state
		croakers.append(croaker)
		
		print("[Race] Created Croaker: %s (Jump: %.1f, Delay: %.1f)" % [
			croaker.name, croaker.jump_distance, croaker.action_delay
		])

func _start_race() -> void:
	print("[Race] Starting race!")
	racing_label.text = "Racing!"
	race_active = true
	race_finished = false

func _process(delta: float) -> void:
	if not race_active or race_finished:
		return
	
	# Update each Croaker's race state
	for i in range(croakers.size()):
		var croaker = croakers[i]
		var racer_visual = racers[i]
		
		# Update Croaker logic
		croaker.update_race_state(delta)
		
		# Convert position to pixels and update visual
		var pixel_position = croaker.position * 10.0  # Scale factor for visibility
		racer_visual.position.x = min(10 + pixel_position, FINISH_LINE)
		
		# Check for race completion
		if pixel_position >= FINISH_LINE - 10:
			if not race_finished:
				_finish_race(croaker)

func _finish_race(winner: Croaker) -> void:
	print("[Race] Race complete! Winner: %s" % winner.name)
	race_finished = true
	race_active = false
	racing_label.text = "Race Complete! Winner: " + winner.name
	
	# Show final positions
	print("[Race] Final positions:")
	for i in range(croakers.size()):
		var croaker = croakers[i]
		var final_position = croaker.position * 10.0
		print("  %d. %s - Distance: %.1f" % [i + 1, croaker.name, final_position])
	
	# Enable back button for easy exit
	back_button.text = "Continue"

func _on_back_pressed() -> void:
	print("[Race] Back button pressed - returning to training")
	GameManager.change_scene("res://scenes/game_flow/training.tscn")
