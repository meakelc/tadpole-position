# eliminated.gd - script for eliminated scene
extends Control

# UI elements
@onready var continue_button: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	print("[Eliminated] Eliminated scene ready")
	
	# Connect button signals
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	GameManager.change_scene("res://scenes/main_menu.tscn")
