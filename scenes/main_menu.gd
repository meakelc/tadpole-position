# main_menu.gd - Main menu scene script for MainMenu.tscn
extends Control

# UI elements (create these as child nodes in MainMenu.tscn)
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	print("[MainMenu] Main menu scene ready")
	
	# Set up UI elements
	title_label.text = "Tadpole Position"
	start_button.text = "Start Race"
	quit_button.text = "Quit"
	
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Optional: Add some visual polish
	start_button.grab_focus()  # Highlight start button by default

func _on_start_pressed() -> void:
	print("[MainMenu] Start button pressed - changing to training scene")
	GameManager.change_scene("res://scenes/game_flow/training.tscn")

func _on_quit_pressed() -> void:
	print("[MainMenu] Quit button pressed - exiting game")
	get_tree().quit()
