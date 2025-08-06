# race_results.gd - Race results scene script for race_results.tscn
extends Control

# UI elements - Podium containers (positions 1-3)
@onready var first_place_container: Control = $HBoxContainer/PodiumContainer/PodiumLabels/Podium1stStageContainer
@onready var second_place_container: Control = $HBoxContainer/PodiumContainer/PodiumLabels/Podium2ndStageContainer
@onready var third_place_container: Control = $HBoxContainer/PodiumContainer/PodiumLabels/Podium3rdStageContainer

# Non-podium placements container (positions 4+)
@onready var non_podium_container: VBoxContainer = $HBoxContainer/NonPodiumPlacements

# Continue button and header
@onready var continue_button: Button = $HBoxContainer/PodiumContainer/ContinueButton
@onready var race_header_label: Label = $HBoxContainer/PodiumContainer/PodiumTitleLabel

# Race results data
var race_results: Array = []
var player_position: int = 0
var current_race_type: String = ""
var is_elimination_race: bool = false
var is_run_based_race: bool = false

func _ready() -> void:
	print("[RaceResults] Race results scene ready")
	
	# Get race results and context from RaceManager (primary source)
	if not _get_race_results_and_context():
		print("[RaceResults] ERROR: No valid race results found! Returning to main menu...")
		GameManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	# Validate that results exist
	if race_results.is_empty():
		print("[RaceResults] ERROR: Empty race results! Returning to appropriate scene...")
		_return_to_fallback_scene()
		return
	
	# Set up header text based on race type and context
	_setup_header_text()
	
	# Populate the podium displays
	populate_podium()
	
	# Populate non-podium placements
	populate_non_podium()
	
	# Set up continue button
	_setup_continue_button()
	
	# Debug output
	_debug_print_results()

func _get_race_results_and_context() -> bool:
	"""
	Get race results and context from RaceManager (primary) with RunManager fallback for run context
	Returns true if successful, false if failed
	"""
	# Primary: Get results from RaceManager
	if not RaceManager:
		print("[RaceResults] ERROR: RaceManager not found!")
		return false
	
	if RaceManager.get_last_race_results().is_empty():
		print("[RaceResults] ERROR: No race results found in RaceManager")
		return false
	
	print("[RaceResults] Using RaceManager for race results")
	
	# Get core race data from RaceManager
	race_results = RaceManager.get_last_race_results()
	player_position = RaceManager.get_last_race_player_position()
	current_race_type = RaceManager.current_race_type
	
	# Determine if this is run-based
	is_run_based_race = (current_race_type == "run_race")
	
	# For run races, get additional context from RunManager
	if is_run_based_race and RunManager and RunManager.is_run_active():
		# Calculate if this was an elimination race based on completed races
		is_elimination_race = (RunManager.races_completed % 3 == 0)
		print("[RaceResults] Run race context - Races completed: %d, Elimination: %s" % [
			RunManager.races_completed, is_elimination_race
		])
	else:
		# Non-run races don't have eliminations
		is_elimination_race = false
	
	print("[RaceResults] Race context - Type: %s, Position: %d/%d, Elimination: %s" % [
		current_race_type, player_position, race_results.size(), is_elimination_race
	])
	
	return true

func _return_to_fallback_scene() -> void:
	"""Return to appropriate fallback scene based on context"""
	if is_run_based_race and RunManager and RunManager.is_run_active():
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
	else:
		GameManager.change_scene("res://scenes/main_menu.tscn")

func _setup_header_text() -> void:
	"""Setup header text based on race type and context"""
	var header_text = ""
	var header_color = Color.WHITE
	
	# Base header text based on race type
	match current_race_type:
		"run_race":
			if is_elimination_race:
				header_text = "ELIMINATION RACE RESULTS"
				header_color = Color.ORANGE_RED
			else:
				var race_num = RunManager.races_completed if RunManager else 1
				header_text = "RACE %d RESULTS" % race_num
		
		"challenge_race":
			header_text = "CHALLENGE RACE RESULTS"
			header_color = Color.ORANGE
		
		"trial_race":
			header_text = "TRIAL RACE RESULTS"
			header_color = Color.CYAN
		
		_:
			header_text = "RACE RESULTS"
	
	# Add player result context
	if player_position == 1:
		match current_race_type:
			"challenge_race":
				header_text += " - CHALLENGE CONQUERED!"
				header_color = Color.GOLD
			"trial_race":
				header_text += " - TRIAL MASTERED!"
				header_color = Color.GOLD
			_:
				header_text += " - VICTORY!"
				header_color = Color.GOLD
	
	elif player_position <= 3:
		match current_race_type:
			"challenge_race":
				header_text += " - CHALLENGE COMPLETED!"
				header_color = Color.SILVER
			"trial_race":
				header_text += " - TRIAL PASSED!"
				header_color = Color.SILVER
			_:
				header_text += " - PODIUM FINISH!"
				header_color = Color.SILVER
	
	elif is_elimination_race and is_run_based_race and player_position > 2:
		header_text += " - ELIMINATED!"
		header_color = Color.CRIMSON
	
	elif current_race_type == "challenge_race" and player_position > 3:
		header_text += " - CHALLENGE FAILED"
		header_color = Color.ORANGE_RED
	
	elif current_race_type == "trial_race" and player_position > 3:
		header_text += " - TRIAL INCOMPLETE"
		header_color = Color.LIGHT_BLUE
	
	# Apply header text and color
	if race_header_label:
		race_header_label.text = header_text
		race_header_label.modulate = header_color
	else:
		print("[RaceResults] No header label found - would display: %s" % header_text)

func populate_podium() -> void:
	"""Populate the podium displays for positions 1-3"""
	
	var podium_containers = [first_place_container, second_place_container, third_place_container]
	var podium_colors = [Color.GOLD, Color.SILVER, Color("#CD7F32")]  # Gold, Silver, Bronze
	var placement_labels = ["1stPlaceLabel", "2ndPlaceLabel", "3rdPlaceLabel"]
	
	for i in range(min(3, race_results.size())):
		var croaker = race_results[i]
		var container = podium_containers[i]
		var placement = i + 1
		
		if not container:
			print("[RaceResults] WARNING: Podium container %d not found" % (i + 1))
			continue
		
		# Update container elements
		var croaker_placeholder = container.get_node_or_null("CroakerPlaceholder")
		var croaker_name = container.get_node_or_null("CroakerName")
		var placement_label = container.get_node_or_null(placement_labels[i])
		
		# Set croaker visual representation
		if croaker_placeholder:
			croaker_placeholder.color = croaker.color_primary
			
			# Add secondary color accent if possible
			var accent = croaker_placeholder.get_node_or_null("Accent")
			if accent:
				accent.color = croaker.color_secondary
		else:
			print("[RaceResults] WARNING: CroakerPlaceholder not found in container %d" % (i + 1))
		
		# Set croaker name and details
		if croaker_name:
			var name_text = croaker.name
			
			# Add (YOU) indicator for player
			if _is_player_croaker(croaker):
				name_text += " (YOU)"
				croaker_name.modulate = Color.CYAN
			else:
				croaker_name.modulate = Color.WHITE
			
			croaker_name.text = name_text
		else:
			print("[RaceResults] WARNING: CroakerName not found in container %d" % (i + 1))
		
		# Set placement number with podium coloring
		if placement_label:
			placement_label.text = _get_ordinal_string(placement)
			placement_label.modulate = podium_colors[i]
		else:
			print("[RaceResults] WARNING: %s not found in container %d" % [placement_labels[i], i + 1])
		
		# Add brand/model info if there's a label for it
		var model_label = container.get_node_or_null("ModelLabel")
		if model_label:
			model_label.text = croaker.get_full_type_name()
		
		print("[RaceResults] Populated podium position %d: %s (%s)" % [
			placement, croaker.name, croaker.get_full_type_name()
		])

func _is_player_croaker(croaker: Croaker) -> bool:
	"""Determine if a croaker is the player's croaker based on context"""
	# For run-based races, check RunManager for player's croaker
	if is_run_based_race and RunManager and RunManager.current_croaker:
		return croaker == RunManager.current_croaker
	
	# For other race types, use RaceManager's race lineup (player should be first)
	if RaceManager and not RaceManager.current_racers.is_empty():
		return croaker == RaceManager.current_racers[0]
	
	# Fallback: player position indicates the player croaker
	if not race_results.is_empty():
		var player_index = player_position - 1
		if player_index >= 0 and player_index < race_results.size():
			return croaker == race_results[player_index]
	
	return false

func populate_non_podium() -> void:
	"""Populate non-podium placements for positions 4+"""
	
	if not non_podium_container:
		print("[RaceResults] WARNING: NonPodiumPlacements container not found")
		return
	
	# Check if we have a template row to use/duplicate
	var template_row = non_podium_container.get_node_or_null("CroakerInfoRowContainer")
	
	if race_results.size() <= 3:
		# No non-podium racers - hide the template if it exists
		if template_row:
			template_row.visible = false
		return
	
	# Clear any existing duplicated rows (keep the original template)
	for child in non_podium_container.get_children():
		if child.name.begins_with("Position") and child != template_row:
			child.queue_free()
	
	# Process positions 4 and beyond
	for i in range(3, race_results.size()):
		var croaker = race_results[i]
		var placement = i + 1
		var row_container: HBoxContainer
		
		if i == 3 and template_row:
			# Use the existing template row for 4th place
			row_container = template_row
			row_container.name = "Position4_Template"  # Keep track that this is the template being used
			row_container.visible = true
		else:
			# Duplicate the template for 5th place and beyond
			if template_row:
				row_container = template_row.duplicate()
				row_container.name = "Position%d" % placement
				row_container.visible = true
				non_podium_container.add_child(row_container)
			else:
				# Create a new row container from scratch if no template exists
				row_container = HBoxContainer.new()
				row_container.name = "Position%d" % placement
				
				# Create placement label
				var new_placement_label = Label.new()
				new_placement_label.name = "PlacementLabel"
				new_placement_label.custom_minimum_size = Vector2(60, 0)
				new_placement_label.add_theme_font_size_override("font_size", 14)
				row_container.add_child(new_placement_label)
				
				# Create croaker placeholder (visual representation)
				var new_croaker_placeholder = ColorRect.new()
				new_croaker_placeholder.name = "CroakerPlaceholder"
				new_croaker_placeholder.custom_minimum_size = Vector2(30, 30)
				row_container.add_child(new_croaker_placeholder)
				
				# Add some spacing
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(10, 0)
				row_container.add_child(spacer)
				
				# Create croaker name label
				var new_name_label = Label.new()
				new_name_label.name = "CroakerNameLabel"
				new_name_label.add_theme_font_size_override("font_size", 14)
				row_container.add_child(new_name_label)
				
				non_podium_container.add_child(row_container)
		
		# Update the row with croaker data
		var placement_label = row_container.get_node_or_null("PlacementLabel")
		if placement_label:
			placement_label.text = _get_ordinal_string(placement)
		
		var croaker_placeholder = row_container.get_node_or_null("CroakerPlaceholder")
		if croaker_placeholder:
			croaker_placeholder.color = croaker.color_primary
		
		var name_label = row_container.get_node_or_null("CroakerNameLabel")
		if name_label:
			var name_text = croaker.name
			if _is_player_croaker(croaker):
				name_text += " (YOU)"
				name_label.modulate = Color.CYAN
			else:
				name_label.modulate = Color.WHITE
			name_label.text = name_text
		
		print("[RaceResults] %s non-podium entry for position %d: %s" % [
			"Updated template" if i == 3 and template_row else "Created",
			placement, 
			croaker.name
		])

func _get_ordinal_string(place: int) -> String:
	"""Convert position number to ordinal string (1st, 2nd, 3rd, 4th, etc.)"""
	
	# Handle special cases for 11th, 12th, 13th
	if place >= 11 and place <= 13:
		return "%dth" % place
	
	# Handle general cases
	var last_digit = place % 10
	match last_digit:
		1:
			return "%dst" % place
		2:
			return "%dnd" % place
		3:
			return "%drd" % place
		_:
			return "%dth" % place

func _setup_continue_button() -> void:
	"""Set up the continue button text and functionality based on race type"""
	
	var button_text = "Continue"
	
	# Customize button text based on race type and outcome
	match current_race_type:
		"run_race":
			if is_elimination_race and player_position > 2:
				button_text = "End Run"
			elif is_elimination_race:
				button_text = "Continue to Next Round"
			else:
				button_text = "Select Warts"
		
		"challenge_race":
			if player_position == 1:
				button_text = "Claim Rewards"
			else:
				button_text = "Try Again"
		
		"trial_race":
			if player_position <= 3:
				button_text = "Complete Trial"
			else:
				button_text = "Retry Trial"
		
		_:
			button_text = "Continue"
	
	continue_button.text = button_text
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Focus the button for keyboard navigation
	continue_button.grab_focus()

func _on_continue_pressed() -> void:
	"""Handle continue button press - transition based on race type and context"""
	
	print("[RaceResults] Continue button pressed for %s" % current_race_type)
	
	match current_race_type:
		"run_race":
			_handle_run_race_continuation()
		
		"challenge_race":
			_handle_challenge_race_continuation()
		
		"trial_race":
			_handle_trial_race_continuation()
		
		_:
			print("[RaceResults] Unknown race type, returning to main menu")
			GameManager.change_scene("res://scenes/main_menu.tscn")

func _handle_run_race_continuation() -> void:
	"""Handle continuation flow for run races"""
	# Check for elimination first (only applies to run races)
	if is_elimination_race and player_position > 2:
		print("[RaceResults] Player eliminated! Ending run...")
		# End the run in RunManager
		if RunManager:
			RunManager.end_current_run()
		# TODO: Transition to run results/game over scene
		# For now, return to main menu
		GameManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	# Check if run is complete (won final race)
	if RunManager and RunManager.is_run_complete():
		print("[RaceResults] Player won the championship!")
		# TODO: Transition to victory scene
		# For now, return to main menu
		GameManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	# Normal progression - go to wart selection or next training round
	print("[RaceResults] Proceeding to next phase...")
	# TODO: Transition to wart selection scene
	# For now, go back to training for next race
	GameManager.change_scene("res://scenes/game_flow/training.tscn")

func _handle_challenge_race_continuation() -> void:
	"""Handle continuation flow for challenge races"""
	if player_position == 1:
		print("[RaceResults] Challenge conquered! Processing rewards...")
		# TODO: Transition to challenge rewards scene
	else:
		print("[RaceResults] Challenge failed, returning to challenge selection...")
		# TODO: Transition to challenge selection scene
	
	# Clear RaceManager state since challenge is complete
	if RaceManager:
		RaceManager.clear_race_state()
	
	# For now, return to main menu
	GameManager.change_scene("res://scenes/main_menu.tscn")

func _handle_trial_race_continuation() -> void:
	"""Handle continuation flow for trial races"""
	if player_position <= 3:
		print("[RaceResults] Trial completed successfully!")
		# TODO: Process trial completion, unlock rewards
	else:
		print("[RaceResults] Trial incomplete, player can retry...")
		# TODO: Offer retry option or return to trial menu
	
	# Clear RaceManager state since trial is complete
	if RaceManager:
		RaceManager.clear_race_state()
	
	# For now, return to main menu
	GameManager.change_scene("res://scenes/main_menu.tscn")

func _debug_print_results() -> void:
	"""Debug output for race results"""
	
	print("[RaceResults] === RACE RESULTS DEBUG ===")
	print("[RaceResults] Race Type: %s | Run-based: %s | Elimination: %s | Player Position: %d" % [
		current_race_type, is_run_based_race, is_elimination_race, player_position
	])
	
	if is_run_based_race and RunManager:
		print("[RaceResults] Run Context - Races completed: %d" % RunManager.races_completed)
	
	if RaceManager:
		var race_stats = RaceManager.get_race_stats()
		print("[RaceResults] RaceManager Stats - Total: %d, Player won: %s, Player podium: %s" % [
			race_stats.get("total_racers", 0),
			race_stats.get("player_won", false),
			race_stats.get("player_podium", false)
		])
	
	for i in range(race_results.size()):
		var croaker = race_results[i]
		var player_indicator = " ★" if _is_player_croaker(croaker) else ""
		print("[RaceResults] %s. %s%s (%s %s)" % [
			_get_ordinal_string(i + 1),
			croaker.name,
			player_indicator,
			croaker.get_brand_name(),
			croaker.get_model_name()
		])
	
	print("[RaceResults] ===========================")

# Optional: Add input handling for quick navigation
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_continue_pressed()
	elif event.is_action_pressed("ui_cancel"):
		# Quick exit to main menu (for testing)
		print("[RaceResults] Quick exit to main menu")
		GameManager.change_scene("res://scenes/main_menu.tscn")
	elif OS.is_debug_build() and event.is_action_pressed("ui_select") and Input.is_action_pressed("ui_cancel"):
		# Debug: Print race context (Ctrl+Esc)
		print("[RaceResults] === DEBUG: Race Context ===")
		print("Race Type: %s" % current_race_type)
		print("Run Based: %s" % is_run_based_race)
		print("Elimination: %s" % is_elimination_race)
		print("Player Position: %d/%d" % [player_position, race_results.size()])
		if RaceManager:
			print("RaceManager Active: %s" % RaceManager.is_race_active())
			print("RaceManager Results Count: %d" % RaceManager.get_last_race_results().size())
		if RunManager:
			print("RunManager Active: %s" % RunManager.is_run_active())
			print("RunManager Races Completed: %d" % RunManager.races_completed)
		print("===============================")
