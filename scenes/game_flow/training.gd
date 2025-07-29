# training.gd - Training scene script for training.tscn
extends Control

# UI elements (create these as child nodes in training.tscn)
@onready var instruction_label: Label = $VBoxContainer/InstructionLabel
@onready var upgrade_button_1: Button = $VBoxContainer/UpgradeContainer/UpgradeButton1
@onready var upgrade_button_2: Button = $VBoxContainer/UpgradeContainer/UpgradeButton2
@onready var upgrade_button_3: Button = $VBoxContainer/UpgradeContainer/UpgradeButton3
@onready var back_button: Button = $VBoxContainer/BackButton

# Sample upgrade options for testing
var upgrade_options: Array[String] = [
	"Jump Boost (+2 Jump Distance)",
	"Speed Training (-0.2 Action Delay)", 
	"Power Leap (+3 Jump, -0.1 Speed)"
]

func _ready() -> void:
	print("[Training] Training scene ready")
	
	# Set up UI elements
	instruction_label.text = "Choose an upgrade for your Croaker:"
	
	# Set button texts to upgrade options
	upgrade_button_1.text = upgrade_options[0]
	upgrade_button_2.text = upgrade_options[1] 
	upgrade_button_3.text = upgrade_options[2]
	
	back_button.text = "Back to Main Menu"
	
	# Connect button signals
	upgrade_button_1.pressed.connect(_on_upgrade_selected.bind(0))
	upgrade_button_2.pressed.connect(_on_upgrade_selected.bind(1))
	upgrade_button_3.pressed.connect(_on_upgrade_selected.bind(2))
	back_button.pressed.connect(_on_back_pressed)
	
	# Focus first upgrade button
	upgrade_button_1.grab_focus()

func _on_upgrade_selected(index: int) -> void:
	print("[Training] Upgrade selected - Index: %d, Upgrade: '%s'" % [index, upgrade_options[index]])
	
	# TODO: Apply upgrade to current Croaker
	# TODO: Move to next training round or race
	
	# For now, show selection feedback
	instruction_label.text = "Selected: " + upgrade_options[index]
	
	# Disable buttons to prevent double-selection
	upgrade_button_1.disabled = true
	upgrade_button_2.disabled = true
	upgrade_button_3.disabled = true
	
	# Add a timer to automatically proceed (for testing)
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(_proceed_after_selection)
	add_child(timer)
	timer.start()

func _proceed_after_selection() -> void:
	print("[Training] Proceeding after upgrade selection...")
	# TODO: Check if more training rounds needed
	# For now, go back to main menu
	GameManager.change_scene("res://scenes/main_menu.tscn")

func _on_back_pressed() -> void:
	print("[Training] Back button pressed - returning to main menu")
	GameManager.change_scene("res://scenes/main_menu.tscn")
