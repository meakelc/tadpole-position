# victory.gd - script for victory scene
extends Control

# UI elements
@onready var continue_button: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	print("[Victory] Victory scene ready")
	
	# Connect button signals
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	GameManager.change_scene("res://scenes/main_menu.tscn")
