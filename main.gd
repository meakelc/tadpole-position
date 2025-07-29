# Main.gd - Root scene script for Main.tscn
extends Control

# UI elements (create these as child nodes in Main.tscn)
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var scene_info_label: Label = $VBoxContainer/SceneInfoLabel
@onready var test_button: Button = $VBoxContainer/TestButton

func _ready() -> void:
	print("[Main] Main scene ready")
	
	# Set up UI
	title_label.text = "TadPole Position - Main Menu"
	scene_info_label.text = "Current Scene: " + GameManager.get_current_scene_name()
	
	# Connect test button
	test_button.text = "Test Scene Change"
	test_button.pressed.connect(_on_test_button_pressed)
	
	# Update scene info every second to show any changes
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_scene_info)
	timer.autostart = true
	add_child(timer)

func _on_test_button_pressed() -> void:
	print("[Main] Test button pressed - attempting scene change")
	# Test scene change (will fail gracefully if TestScene.tscn doesn't exist)
	GameManager.change_scene("res://scenes/test_scene.tscn")

func _update_scene_info() -> void:
	if scene_info_label:
		scene_info_label.text = "Current Scene: " + GameManager.get_current_scene_name()
