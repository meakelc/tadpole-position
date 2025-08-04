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
	if GameManager.current_croaker:
		continue_button.grab_focus()
	else:
		start_button.grab_focus()

func _update_menu_state() -> void:
	# Show/hide continue button based on whether there's an active run
	if GameManager.current_croaker:
		continue_button.visible = true
		croaker_info_label.visible = true
		croaker_info_label.text = "Current Run: %s (Jump: %.1f, Speed: %.1f)" % [
			GameManager.current_croaker.name,
			GameManager.current_croaker.jump_distance,
			GameManager.current_croaker.action_delay
		]
	else:
		continue_button.visible = false
		croaker_info_label.visible = false

func _on_start_pressed() -> void:
	print("[MainMenu] Start button pressed - beginning new run")
	
	# Clear any existing run
	GameManager.current_croaker = null
	GameManager.ai_croakers.clear()
	
	# Start fresh training
	GameManager.change_scene("res://scenes/game_flow/training.tscn")

func _on_continue_pressed() -> void:
	if not GameManager.current_croaker:
		print("[MainMenu] No active run to continue")
		return
	
	print("[MainMenu] Continue button pressed - resuming run")
	# Go directly to race since training is already done
	GameManager.change_scene("res://scenes/game_flow/race.tscn")

func _on_quit_pressed() -> void:
	print("[MainMenu] Quit button pressed - exiting game")
	get_tree().quit()
