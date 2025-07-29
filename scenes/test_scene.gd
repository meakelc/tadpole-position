# TestScene.gd - Simple test scene to verify scene changes work
extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	print("[TestScene] Test scene ready")
	
	# Set up UI
	title_label.text = "Test Scene - Scene Change Working!"
	back_button.text = "Back to Main"
	back_button.pressed.connect(_on_back_button_pressed)

func _on_back_button_pressed() -> void:
	print("[TestScene] Back button pressed - returning to main")
	GameManager.change_scene("res://main.tscn")
