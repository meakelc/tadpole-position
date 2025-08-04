# race.gd - Race scene script with RunManager integration
extends Control

# UI elements
@onready var racing_label: Label = $VBoxContainer/RacingLabel
@onready var track_container: Control = $VBoxContainer/TrackContainer
@onready var continue_button: Button = $VBoxContainer/ContinueButton

# Racer visuals - will be created dynamically
var racer_visuals: Array[Control] = []

# Racing state
var croakers: Array[Croaker] = []

# Track settings
const TRACK_WIDTH := 1000
const RACER_HEIGHT := 40
const RACER_BASE_WIDTH := 60
const LANE_HEIGHT := 60
const FINISH_LINE := TRACK_WIDTH - 50

# Race state
var race_active := false
var race_finished := false
var race_results: Array[Croaker] = []

func _ready() -> void:
	print("[Race] Race scene ready")
	
	# Validate RunManager is available and has active run
	if not RunManager:
		print("[Race] ERROR: RunManager not found! Returning to main menu...")
		GameManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	if not RunManager.is_run_active():
		print("[Race] ERROR: No active run found! Returning to training...")
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
		return
	
	# Verify we have a Croaker from RunManager
	if not RunManager.current_croaker:
		print("[Race] ERROR: No current Croaker found in RunManager! Returning to training...")
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
		return
	
	# Set up UI elements
	racing_label.text = "Get Ready..."
	continue_button.text = "Skip Race"
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Get race lineup from RunManager
	croakers = RunManager.get_race_lineup()
	
	if croakers.is_empty():
		print("[Race] ERROR: Empty race lineup from RunManager! Returning to training...")
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
		return
	
	# Create racer visuals based on Croaker data
	_create_racer_visuals()
	
	# Position and style racers
	_setup_racers()
	
	# Start race after a brief delay
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_start_race)
	add_child(timer)
	timer.start()

func _create_racer_visuals() -> void:
	# Clear any existing visuals
	for child in track_container.get_children():
		if child is Control and child != track_container:
			child.queue_free()
	racer_visuals.clear()
	
	# Create visual for each Croaker
	for i in range(croakers.size()):
		var croaker = croakers[i]
		
		# Create container for racer
		var racer_container = Control.new()
		racer_container.name = "Racer%d" % (i + 1)
		track_container.add_child(racer_container)
		
		# Create the main body (ColorRect for now, will be sprite later)
		var racer_body = ColorRect.new()
		racer_body.name = "Body"
		racer_body.color = croaker.color_primary
		racer_body.size = Vector2(RACER_BASE_WIDTH * croaker.size_modifier, RACER_HEIGHT * croaker.size_modifier)
		racer_container.add_child(racer_body)
		
		# Add secondary color accent (stripe or detail)
		var accent = ColorRect.new()
		accent.name = "Accent"
		accent.color = croaker.color_secondary
		accent.size = Vector2(racer_body.size.x * 0.3, racer_body.size.y * 0.6)
		accent.position = Vector2(racer_body.size.x * 0.6, racer_body.size.y * 0.2)
		racer_body.add_child(accent)
		
		# Add name label above racer
		var name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = croaker.name
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.position = Vector2(0, -25)
		racer_container.add_child(name_label)
		
		# Add model label below name
		var model_label = Label.new()
		model_label.name = "ModelLabel"
		model_label.text = croaker.get_full_type_name()
		model_label.add_theme_font_size_override("font_size", 10)
		model_label.position = Vector2(0, -10)
		racer_container.add_child(model_label)
		
		# Store reference
		racer_visuals.append(racer_container)

func _setup_racers() -> void:
	# Set up track container size
	track_container.custom_minimum_size = Vector2(TRACK_WIDTH, LANE_HEIGHT * 4)
	
	# Position each racer in their lane
	for i in range(croakers.size()):
		var croaker = croakers[i]
		var racer_visual = racer_visuals[i]
		
		# Position at start of their lane
		var lane_y = i * LANE_HEIGHT + (LANE_HEIGHT - RACER_HEIGHT) / 2.0
		racer_visual.position = Vector2(10, lane_y)
		
		# Assign visual node to Croaker and reset state
		croaker.set_visual_node(racer_visual)
		croaker.reset_race_state()
		
		# Log stats for debugging
		print("[Race] Lane %d: %s (%s %s)" % [
			i + 1,
			croaker.name,
			croaker.get_brand_name(),
			croaker.get_model_name()
		])
		print("  Stats - Jump: %.1f, Delay: %.1f, Personality: %s" % [
			croaker.jump_distance,
			croaker.action_delay,
			croaker.personality
		])
	
	# Add lane dividers for clarity
	for i in range(1, 4):
		var divider = ColorRect.new()
		divider.color = Color(0.3, 0.3, 0.3, 0.5)
		divider.size = Vector2(TRACK_WIDTH, 2)
		divider.position = Vector2(0, i * LANE_HEIGHT - 1)
		track_container.add_child(divider)
	
	# Add finish line
	var finish_line_visual = ColorRect.new()
	finish_line_visual.color = Color.WHITE
	finish_line_visual.size = Vector2(4, LANE_HEIGHT * 4)
	finish_line_visual.position = Vector2(FINISH_LINE, 0)
	track_container.add_child(finish_line_visual)
	
	# Highlight player's lane (player should be first in lineup from RunManager)
	if croakers[0] == RunManager.current_croaker:
		var highlight = ColorRect.new()
		highlight.color = Color(0.2, 0.8, 0.2, 0.1)
		highlight.size = Vector2(TRACK_WIDTH, LANE_HEIGHT)
		highlight.position = Vector2(0, 0)
		highlight.z_index = -1
		track_container.add_child(highlight)

func _start_race() -> void:
	print("[Race] Starting race!")
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
		var racer_visual = racer_visuals[i]
		
		# Skip if already finished
		if croaker in race_results:
			continue
		
		# Update Croaker logic
		croaker.update_race_state(delta)
		
		# Convert position to pixels and update visual
		var pixel_position = croaker.position * 10.0  # Scale factor for visibility
		racer_visual.position.x = min(10 + pixel_position, FINISH_LINE + 50)
		
		# Add jump animation when action performed
		if croaker.action_cooldown > croaker.action_delay - 0.1:
			var tween = create_tween()
			var body = racer_visual.get_node("Body")
			tween.tween_property(body, "position:y", -10, 0.1)
			tween.tween_property(body, "position:y", 0, 0.1)
		
		# Check for race completion
		if pixel_position >= FINISH_LINE:
			_croaker_finished(croaker)
			
			# Check if all racers finished
			if race_results.size() == croakers.size():
				_finish_race()

func _croaker_finished(croaker: Croaker) -> void:
	if croaker not in race_results:
		race_results.append(croaker)
		var finishing_position = race_results.size()
		print("[Race] %s (%s) finished in position %d!" % [
			croaker.name,
			croaker.get_full_type_name(),
			finishing_position
		])
		
		# Special message for player
		if croaker == RunManager.current_croaker:
			racing_label.text = "You finished #%d!" % finishing_position

func _finish_race() -> void:
	print("[Race] Race complete!")
	race_finished = true
	race_active = false
	
	# Store race results in RunManager
	RunManager.store_race_results(race_results.duplicate())
	
	# Find player position for UI display
	var player_finishing_position = race_results.find(RunManager.current_croaker) + 1
	
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
	
	# Show final results with full details
	print("[Race] Final Results:")
	for i in range(race_results.size()):
		var croaker = race_results[i]
		print("  %d. %s (%s %s) - Jump: %.1f, Delay: %.1f" % [
			i + 1,
			croaker.name,
			croaker.get_brand_name(),
			croaker.get_model_name(),
			croaker.jump_distance,
			croaker.action_delay
		])
	
	# Update button
	continue_button.text = "Continue"

func _on_continue_pressed() -> void:
	if race_finished:
		print("[Race] Race complete - results stored in RunManager")
		
		# Get current race number and player position from RunManager
		var current_race_number = RunManager.races_completed
		var player_position = RunManager.get_last_race_player_position()
		
		# Check for elimination
		if current_race_number % 3 == 0:  # Every 3rd race is elimination
			print("[Race] This was an elimination race!")
			if player_position > 2:  # Bottom 2 eliminated
				print("[Race] Player eliminated!")
				GameManager.change_scene("res://scenes/game_flow/run_results.tscn")
				return
		
		# Check if run is complete (won championship)
		if RunManager.is_run_complete():
			print("[Race] Run complete! Proceeding to final results...")
			GameManager.change_scene("res://scenes/game_flow/run_results.tscn")
			return
		
		# Continue to post-race rewards
		GameManager.change_scene("res://scenes/game_flow/race_results.tscn")
	else:
		print("[Race] Skipping race")
		
		# Create simulated race results for skipped races
		var all_racers = RunManager.get_race_lineup()
		all_racers.shuffle()  # Random finish order for simulation
		
		# Store simulated results in RunManager
		RunManager.store_race_results(all_racers.duplicate())
		
		# Continue with the simulated results
		GameManager.change_scene("res://scenes/game_flow/race_results.tscn")
