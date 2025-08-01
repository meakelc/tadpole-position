# pre_race.gd - Pre-race preparation scene script
extends Control

# UI elements (create these as child nodes in pre_race.tscn)
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var start_race_button: Button = $VBoxContainer/StartRaceButton

func _ready() -> void:
	print("[PreRace] Pre-race scene ready")
	
	# Set up UI elements
	title_label.text = "Prepare to Race"
	start_race_button.text = "Start Race!"
	
	# Connect button signal
	start_race_button.pressed.connect(_on_start_race_pressed)
	
	# Focus the start button for keyboard navigation
	start_race_button.grab_focus()
	
	# Optional: Add some preparation time or show race info here
	_setup_race_info()

func _setup_race_info() -> void:
	# Placeholder for future race preparation logic
	# Could show:
	# - Current Croaker stats
	# - Opponent preview
	# - Track conditions
	# - Strategy selection (future feature)
	print("[PreRace] Race preparation complete")

func _on_start_race_pressed() -> void:
	print("[PreRace] Start Race button pressed - transitioning to race scene")
	# Transition to the actual race scene
	GameManager.change_scene("res://scenes/game_flow/race.tscn")
