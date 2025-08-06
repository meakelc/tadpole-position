# race.gd - Race scene script with RaceManager integration
# Supports all race types: run races, challenge races, trial races
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

# Race context - determines post-race flow
var current_race_type: String = "run_race"  # Default to run race
var is_run_based_race: bool = true

func _ready() -> void:
	print("[Race] Race scene ready")
	
	# Validate that we have either RaceManager or RunManager available
	if not _validate_race_managers():
		print("[Race] ERROR: No valid race managers found! Returning to main menu...")
		GameManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	# Determine race context and get racers
	if not _setup_race_context():
		print("[Race] ERROR: Failed to setup race context! Returning to appropriate scene...")
		_return_to_fallback_scene()
		return
	
	# Set up UI elements
	_setup_ui()
	
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

func _validate_race_managers() -> bool:
	"""Validate that at least one race manager is available"""
	if not RaceManager and not RunManager:
		print("[Race] ERROR: Neither RaceManager nor RunManager found!")
		return false
	
	if not RaceManager:
		print("[Race] WARNING: RaceManager not found, using RunManager only")
	
	if not RunManager:
		print("[Race] WARNING: RunManager not found, using RaceManager only")
	
	return true

func _setup_race_context(player_croaker: Croaker, ai_croakers: Array[Croaker], race_type: String = "run_race", config: Dictionary = {}) -> bool:
	"""
	Setup race context by determining race type and getting racers
	Returns true if successful, false if failed
	"""
	# Check if we have an active RaceManager race
	if RaceManager and not RaceManager.is_race_active():
		print("[Race] Using active RaceManager race")
		current_race_type = RaceManager.config_current_race(player_croaker, ai_croakers, race_type, config)
		is_run_based_race = (current_race_type == "run_race")
		croakers = RaceManager.current_racers.duplicate()
		
		print("[Race] RaceManager context - Type: %s, Racers: %d" % [current_race_type, croakers.size()])
		return not croakers.is_empty()
	
	# No active race context found
	else:
		print("[Race] ERROR: No active race context found")
		return false

func _setup_ui() -> void:
	"""Setup UI elements based on race type"""
	# Set initial racing label
	racing_label.text = "Get Ready..."
	
	# Set continue button text based on race type
	match current_race_type:
		"run_race":
			continue_button.text = "Skip Race"
		"challenge_race":
			continue_button.text = "Skip Challenge"
		"trial_race":
			continue_button.text = "Skip Trial"
		_:
			continue_button.text = "Skip Race"
	
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Apply race type specific styling
	match current_race_type:
		"challenge_race":
			racing_label.modulate = Color.ORANGE
		"trial_race":
			racing_label.modulate = Color.CYAN
		_:
			racing_label.modulate = Color.WHITE

func _return_to_fallback_scene() -> void:
	"""Return to appropriate fallback scene based on context"""
	if is_run_based_race and RunManager and RunManager.is_run_active():
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
	else:
		GameManager.change_scene("res://scenes/main_menu.tscn")

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
	# Set up track container size based on racer count
	var lane_count = max(croakers.size(), 4)  # Minimum 4 lanes for visual consistency
	track_container.custom_minimum_size = Vector2(TRACK_WIDTH, LANE_HEIGHT * lane_count)
	
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
	for i in range(1, lane_count):
		var divider = ColorRect.new()
		divider.color = Color(0.3, 0.3, 0.3, 0.5)
		divider.size = Vector2(TRACK_WIDTH, 2)
		divider.position = Vector2(0, i * LANE_HEIGHT - 1)
		track_container.add_child(divider)
	
	# Add finish line
	var finish_line_visual = ColorRect.new()
	finish_line_visual.color = Color.WHITE
	finish_line_visual.size = Vector2(4, LANE_HEIGHT * lane_count)
	finish_line_visual.position = Vector2(FINISH_LINE, 0)
	track_container.add_child(finish_line_visual)
	
	# Highlight player's lane (player should be first in lineup)
	_highlight_player_lane()

func _highlight_player_lane() -> void:
	"""Highlight the player's lane based on race context"""
	var player_croaker: Croaker = null
	
	# Find player Croaker based on context
	if is_run_based_race and RunManager and RunManager.current_croaker:
		player_croaker = RunManager.current_croaker
	elif not croakers.is_empty():
		# For non-run races, assume first racer is player
		player_croaker = croakers[0]
	
	if not player_croaker:
		return
	
	# Find player's lane index
	var player_lane_index = croakers.find(player_croaker)
	if player_lane_index == -1:
		return
	
	# Create highlight for player's lane
	var highlight = ColorRect.new()
	highlight.color = Color(0.2, 0.8, 0.2, 0.1)
	highlight.size = Vector2(TRACK_WIDTH, LANE_HEIGHT)
	highlight.position = Vector2(0, player_lane_index * LANE_HEIGHT)
	highlight.z_index = -1
	track_container.add_child(highlight)

func _start_race() -> void:
	print("[Race] Starting %s!" % current_race_type)
	race_active = true
	race_finished = false
	race_results.clear()
	
	# Add countdown effect with race type context
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
		
		# Special message for player (context-aware)
		var player_croaker = _get_player_croaker()
		if croaker == player_croaker:
			racing_label.text = "You finished #%d!" % finishing_position

func _get_player_croaker() -> Croaker:
	"""Get the player's Croaker based on race context"""
	if is_run_based_race and RunManager and RunManager.current_croaker:
		return RunManager.current_croaker
	elif not croakers.is_empty():
		# For non-run races, assume first racer is player
		return croakers[0]
	else:
		return null

func _finish_race() -> void:
	print("[Race] %s complete!" % current_race_type)
	race_finished = true
	race_active = false
	
	# Store race results in RaceManager (primary)
	_store_race_results()
	
	# Find player position for UI display
	var player_croaker = _get_player_croaker()
	var player_finishing_position = race_results.find(player_croaker) + 1 if player_croaker else 0
	
	# Update UI based on result and race type
	_update_finish_ui(player_finishing_position)
	
	# Show final results with full details
	_debug_print_final_results()
	
	# Update button text
	continue_button.text = _get_continue_button_text()

func _store_race_results() -> void:
	"""Store race results in RaceManager (centralized race result management)"""
	if not RaceManager:
		print("[Race] ERROR: RaceManager not available to store results!")
		return
	
	# End the race in RaceManager (this stores the results)
	var success = RaceManager.end_race(race_results.duplicate())
	
	if success:
		print("[Race] Results successfully stored in RaceManager")
	else:
		print("[Race] WARNING: Failed to store results in RaceManager")

func _update_finish_ui(player_finishing_position: int) -> void:
	"""Update UI based on finish position and race type"""
	if player_finishing_position <= 0:
		racing_label.text = "Race Complete!"
		racing_label.modulate = Color.WHITE
		return
	
	# Base message based on position
	var message = ""
	var color = Color.WHITE
	
	if player_finishing_position == 1:
		match current_race_type:
			"challenge_race":
				message = "Challenge Conquered!"
				color = Color.GOLD
			"trial_race":
				message = "Trial Mastered!"
				color = Color.CYAN
			_:
				message = "Victory! You won the race!"
				color = Color.GOLD
	elif player_finishing_position <= 2:
		message = "Great job! You finished #%d!" % player_finishing_position
		color = Color.SILVER
	else:
		match current_race_type:
			"challenge_race":
				message = "Challenge failed. Finished #%d" % player_finishing_position
				color = Color.ORANGE_RED
			"trial_race":
				message = "Trial incomplete. Finished #%d" % player_finishing_position
				color = Color.LIGHT_BLUE
			_:
				message = "You finished #%d. Keep training!" % player_finishing_position
				color = Color.TAN
	
	racing_label.text = message
	racing_label.modulate = color

func _get_continue_button_text() -> String:
	"""Get appropriate continue button text based on race type"""
	match current_race_type:
		"challenge_race":
			return "Continue"
		"trial_race":
			return "Finish Trial"
		_:
			return "Continue"

func _debug_print_final_results() -> void:
	"""Debug output for final race results"""
	print("[Race] === FINAL %s RESULTS ===" % current_race_type.to_upper())
	for i in range(race_results.size()):
		var croaker = race_results[i]
		var player_indicator = ""
		
		var player_croaker = _get_player_croaker()
		if croaker == player_croaker:
			player_indicator = " ★ (PLAYER)"
		
		print("  %d. %s%s (%s %s) - Jump: %.1f, Delay: %.1f" % [
			i + 1,
			croaker.name,
			player_indicator,
			croaker.get_brand_name(),
			croaker.get_model_name(),
			croaker.jump_distance,
			croaker.action_delay
		])
	print("=======================================")

func _on_continue_pressed() -> void:
	"""Handle continue button press - context-aware transition"""
	if race_finished:
		print("[Race] Race complete - handling post-race flow for %s" % current_race_type)
		_handle_post_race_flow()
	else:
		print("[Race] Skipping %s" % current_race_type)
		_handle_race_skip()

func _handle_post_race_flow() -> void:
	"""Handle post-race flow based on race type and context"""
	match current_race_type:
		"run_race":
			_handle_run_race_completion()
		"challenge_race":
			_handle_challenge_race_completion()
		"trial_race":
			_handle_trial_race_completion()
		_:
			print("[Race] Unknown race type '%s', returning to main menu" % current_race_type)
			GameManager.change_scene("res://scenes/main_menu.tscn")

func _handle_run_race_completion() -> void:
	"""Handle completion of a run-based race"""
	if not RunManager or not RunManager.is_run_active():
		print("[Race] ERROR: No active run for run race completion")
		GameManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	# Get player position from RaceManager (primary source)
	var player_position = 0
	if RaceManager:
		player_position = RaceManager.get_last_race_player_position()
	
	# Fallback to direct calculation if RaceManager unavailable
	if player_position <= 0:
		var player_croaker = _get_player_croaker()
		if player_croaker:
			player_position = race_results.find(player_croaker) + 1
	
	# Check for elimination
	if RunManager.is_next_race_elimination():  # Check if LAST race was elimination
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

func _handle_challenge_race_completion() -> void:
	"""Handle completion of a challenge race"""
	print("[Race] Challenge race completed")
	# TODO: Implement challenge-specific post-race flow
	# For now, return to main menu
	# Future: Go to challenge results scene or challenge menu
	GameManager.change_scene("res://scenes/main_menu.tscn")

func _handle_trial_race_completion() -> void:
	"""Handle completion of a trial race"""
	print("[Race] Trial race completed")
	# TODO: Implement trial-specific post-race flow
	# For now, return to main menu
	# Future: Go to trial results scene or trial menu
	GameManager.change_scene("res://scenes/main_menu.tscn")

func _handle_race_skip() -> void:
	"""Handle skipping the race - create simulated results"""
	print("[Race] Simulating %s results" % current_race_type)
	
	# Create simulated race results for skipped races
	var all_racers = croakers.duplicate()
	all_racers.shuffle()  # Random finish order for simulation
	
	# Store simulated results
	race_results = all_racers.duplicate()
	_store_race_results()
	
	# Handle post-race flow based on type
	_handle_post_race_flow()

# Optional: Add debug input handling for testing different race types
func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("ui_cancel"):
		if Input.is_action_pressed("ui_select"):
			# Debug: Print race context info (Ctrl+Esc)
			print("[Race] === DEBUG: Race Context ===")
			print("Race Type: %s" % current_race_type)
			print("Run Based: %s" % is_run_based_race)
			print("RaceManager Active: %s" % (RaceManager.is_race_active() if RaceManager else false))
			print("RunManager Active: %s" % (RunManager.is_run_active() if RunManager else false))
			print("Racers: %d" % croakers.size())
			if RaceManager:
				var last_position = RaceManager.get_last_race_player_position()
				print("Last Race Player Position: %d" % last_position)
			print("===============================")
