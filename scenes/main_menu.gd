# main_menu.gd - Main menu scene script for MainMenu.tscn
extends Control

# UI elements (create these as child nodes in MainMenu.tscn)
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var croaker_info_label: Label = $VBoxContainer/CroakerInfoLabel

func _ready() -> void:
	print("[MainMenu] Main menu scene ready")
	
	# Validate RunManager is available
	if not RunManager:
		print("[MainMenu] ERROR: RunManager not found! Menu may not function correctly.")
		# Continue with limited functionality
	
	# Set up UI elements
	title_label.text = "Tadpole Position"
	start_button.text = "New Run"
	continue_button.text = "Continue Run"
	quit_button.text = "Quit"
	
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Update UI based on game state
	_update_menu_state()
	
	# Focus appropriate button
	if RunManager and RunManager.is_run_active():
		continue_button.grab_focus()
	else:
		start_button.grab_focus()

func _update_menu_state() -> void:
	"""Update menu visibility and info based on current run state"""
	
	# Check if RunManager is available and has an active run
	var has_active_run = RunManager and RunManager.is_run_active()
	
	if has_active_run:
		# Show continue option and croaker info
		continue_button.visible = true
		croaker_info_label.visible = true
		
		# Get current croaker info
		var current_croaker = RunManager.current_croaker
		if current_croaker:
			croaker_info_label.text = "Current Run: %s (%s)\nJump: %.1f | Speed: %.1f | Races: %d" % [
				current_croaker.name,
				current_croaker.get_full_type_name(),
				current_croaker.jump_distance,
				current_croaker.action_delay,
				RunManager.races_completed
			]
		else:
			# RunManager says run is active but no croaker found
			print("[MainMenu] WARNING: RunManager reports active run but no current_croaker found")
			croaker_info_label.text = "Active Run (Croaker data missing)"
	else:
		# Hide continue option and croaker info
		continue_button.visible = false
		croaker_info_label.visible = false
		
		# Log why no active run
		if not RunManager:
			print("[MainMenu] No continue option - RunManager not available")
		elif RunManager.current_croaker == null:
			print("[MainMenu] No continue option - No current croaker")
		else:
			print("[MainMenu] No continue option - Run not active")

func _on_start_pressed() -> void:
	print("[MainMenu] Start button pressed - beginning new run")
	
	# Validate RunManager is available
	if not RunManager:
		print("[MainMenu] ERROR: RunManager not available, cannot start new run")
		# TODO: Show error dialog to user
		return
	
	# End any existing run through RunManager
	if RunManager.is_run_active():
		print("[MainMenu] Ending existing run before starting new one")
		RunManager.end_current_run()
	
	# Start new run through RunManager
	var success = RunManager.start_new_run("Player Frog")
	if not success:
		print("[MainMenu] ERROR: Failed to start new run")
		# TODO: Show error dialog to user
		return
	
	# Navigate to training scene using GameManager
	GameManager.change_scene("res://scenes/game_flow/training.tscn")

func _on_continue_pressed() -> void:
	# Validate we have an active run to continue
	if not RunManager or not RunManager.is_run_active():
		print("[MainMenu] ERROR: No active run to continue")
		_update_menu_state()  # Refresh menu state
		return
	
	print("[MainMenu] Continue button pressed - resuming run")
	
	# Determine where to continue based on run state
	if RunManager.races_completed == 0:
		# No races completed yet - go to training
		print("[MainMenu] Continuing to training (no races completed)")
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
	elif RunManager.is_run_complete():
		# Run is complete - should not be able to continue
		print("[MainMenu] WARNING: Trying to continue completed run")
		RunManager.end_current_run()
		_update_menu_state()
		return
	else:
		# Races completed but run not finished - continue to next training
		print("[MainMenu] Continuing to training (run in progress)")
		GameManager.change_scene("res://scenes/game_flow/training.tscn")

func _on_quit_pressed() -> void:
	print("[MainMenu] Quit button pressed - exiting game")
	get_tree().quit()

# Optional: Add debug functionality for testing
func _input(event: InputEvent) -> void:
	# Debug key combinations (only in debug builds)
	if OS.is_debug_build():
		if event.is_action_pressed("ui_select") and Input.is_action_pressed("ui_accept"):
			# Debug: Print run state (Ctrl+Enter or similar)
			print("[MainMenu] === DEBUG: Current State ===")
			if RunManager:
				RunManager.debug_print_run_state()
			else:
				print("[MainMenu] RunManager not available")
			print("=====================================")
		elif event.is_action_pressed("ui_cancel") and Input.is_action_pressed("ui_select"):
			# Debug: Force end current run (Ctrl+Esc or similar)
			if RunManager and RunManager.is_run_active():
				print("[MainMenu] DEBUG: Force ending current run")
				RunManager.end_current_run()
				_update_menu_state()
