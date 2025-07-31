# race.gd - Race scene script for race.tscn
extends Control

# UI elements (create these as child nodes in race.tscn)
@onready var racing_label: Label = $VBoxContainer/RacingLabel
@onready var track_container: Control = $VBoxContainer/TrackContainer
@onready var racer_1: ColorRect = $VBoxContainer/TrackContainer/Racer1
@onready var racer_2: ColorRect = $VBoxContainer/TrackContainer/Racer2
@onready var racer_3: ColorRect = $VBoxContainer/TrackContainer/Racer3
@onready var racer_4: ColorRect = $VBoxContainer/TrackContainer/Racer4
@onready var continue_button: Button = $VBoxContainer/ContinueButton

# Racing state
var racers: Array[ColorRect] = []
var croakers: Array[Croaker] = []

# Track settings
const TRACK_WIDTH := 1000
const RACER_SIZE := Vector2(40, 30)
const LANE_HEIGHT := 50
const FINISH_LINE := TRACK_WIDTH - 50  # Leave some space before the edge

# Race state
var race_active := false
var race_finished := false
var race_results: Array[Croaker] = []  # Track finishing order

func _ready() -> void:
	print("[Race] Race scene ready")
	
	# Verify we have a Croaker from training
	if not GameManager.current_croaker:
		print("[Race] ERROR: No Croaker found! Returning to training...")
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
		return
	
	# Set up UI elements
	racing_label.text = "Get Ready..."
	continue_button.text = "Skip Race"
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Initialize racers array
	racers = [racer_1, racer_2, racer_3, racer_4]
	
	# Position and style racers
	_setup_racers()
	
	# Get race lineup from GameManager
	_setup_croakers()
	
	# Start race after a brief delay
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_start_race)
	add_child(timer)
	timer.start()

func _setup_racers() -> void:
	# Set up track container size
	track_container.custom_minimum_size = Vector2(TRACK_WIDTH, LANE_HEIGHT * 4)
	
	# Colors for each racer
	var racer_colors: Array[Color] = [
		Color.GREEN,   # Player Croaker (always green)
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
		
		# Add a label to show racer name
		var name_label = Label.new()
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.position = Vector2(0, -20)
		racer.add_child(name_label)

func _setup_croakers() -> void:
	# Get race lineup from GameManager
	croakers = GameManager.get_race_lineup()
	
	if croakers.size() != 4:
		print("[Race] ERROR: Expected 4 racers, got %d" % croakers.size())
		return
	
	# Assign visual nodes and reset race state
	for i in range(croakers.size()):
		var croaker = croakers[i]
		croaker.set_visual_node(racers[i])
		croaker.reset_race_state()
		
		# Update name label
		var name_label = racers[i].get_child(0) as Label
		if name_label:
			name_label.text = croaker.name
		
		# Log stats for debugging
		print("[Race] Lane %d: %s (Jump: %.1f, Delay: %.1f)" % [
			i + 1, croaker.name, croaker.jump_distance, croaker.action_delay
		])
	
	# Highlight that we're using the upgraded player Croaker
	print("[Race] Player Croaker stats after training:")
	GameManager.debug_print_croaker_stats()

func _start_race() -> void:
	print("[Race] Starting race!")
	racing_label.text = "GO!"
	race_active = true
	race_finished = false
	race_results.clear()
	
	# Add countdown effect
	var countdown_texts = ["3...", "2...", "1...", "GO!"]
	for i in range(countdown_texts.size()):
		await get_tree().create_timer(0.5).timeout
		racing_label.text = countdown_texts[i]

func _process(delta: float) -> void:
	if not race_active or race_finished:
		return
	
	# Update each Croaker's race state
	for i in range(croakers.size()):
		var croaker = croakers[i]
		var racer_visual = racers[i]
		
		# Skip if already finished
		if croaker in race_results:
			continue
		
		# Update Croaker logic
		croaker.update_race_state(delta)
		
		# Convert position to pixels and update visual
		var pixel_position = croaker.position * 10.0  # Scale factor for visibility
		racer_visual.position.x = min(10 + pixel_position, FINISH_LINE + 50)
		
		# Check for race completion
		if pixel_position >= FINISH_LINE:
			_croaker_finished(croaker)
			
			# Check if all racers finished
			if race_results.size() == croakers.size():
				_finish_race()

func _croaker_finished(croaker: Croaker) -> void:
	if croaker not in race_results:
		race_results.append(croaker)
		var finishing_position = race_results.size()  # Renamed from 'position'
		print("[Race] %s finished in position %d!" % [croaker.name, finishing_position])
		
		# Special message for player
		if croaker == GameManager.current_croaker:
			racing_label.text = "You finished #%d!" % finishing_position

func _finish_race() -> void:
	print("[Race] Race complete!")
	race_finished = true
	race_active = false
	
	# Find player position
	var player_finishing_position = race_results.find(GameManager.current_croaker) + 1  # Renamed for consistency
	
	# Update UI based on result
	if player_finishing_position == 1:
		racing_label.text = "Victory! You won the race!"
		racing_label.modulate = Color.GOLD
	elif player_finishing_position <= 2:
		racing_label.text = "Great job! You finished #%d!" % player_finishing_position
		racing_label.modulate = Color.SILVER
	else:
		racing_label.text = "You finished #%d. Keep training!" % player_finishing_position
		racing_label.modulate = Color.TAN
	
	# Show final results
	print("[Race] Final Results:")
	for i in range(race_results.size()):
		var croaker = race_results[i]
		print("  %d. %s (Jump: %.1f, Delay: %.1f)" % [
			i + 1, 
			croaker.name, 
			croaker.jump_distance, 
			croaker.action_delay
		])
	
	# Update button
	continue_button.text = "Continue"

func _on_continue_pressed() -> void:
	if race_finished:
		print("[Race] Race complete - transition to race results")
		# TODO: In full game, this would go to wart selection or next race
		GameManager.change_scene("res://scenes/game_flow/race_results.tscn")
	else:
		print("[Race] Skipping race - transition to race results")
		GameManager.change_scene("res://scenes/game_flow/race_results.tscn")
