# race_results.gd - Race scene script for race.tscn
extends Control

# UI elements
@onready var first_place_croaker: ColorRect = $HBoxContainer/PodiumContainer/PodiumLabels/Podium1stStageContainer/CroakerPlaceholder
@onready var second_place_croaker: ColorRect = $HBoxContainer/PodiumContainer/PodiumLabels/Podium2ndStageContainer/CroakerPlaceholder
@onready var third_place_croaker: ColorRect = $HBoxContainer/PodiumContainer/PodiumLabels/Podium3rdStageContainer/CroakerPlaceholder
@onready var fourth_place_croaker: ColorRect = $HBoxContainer/NonPodiumPlacements/CroakerInfoRowContainer/CroakerPlaceholder
@onready var first_place_croaker_name: Label = $HBoxContainer/PodiumContainer/PodiumLabels/Podium1stStageContainer/CroakerName
@onready var second_place_croaker_name: Label = $HBoxContainer/PodiumContainer/PodiumLabels/Podium2ndStageContainer/CroakerName
@onready var third_place_croaker_name: Label = $HBoxContainer/PodiumContainer/PodiumLabels/Podium3rdStageContainer/CroakerName
@onready var fourth_place_croaker_name: Label = $HBoxContainer/NonPodiumPlacements/CroakerInfoRowContainer/CroakerNameLabel
@onready var continue_button: Button = $HBoxContainer/PodiumContainer/ContinueButton

func _ready() -> void:
	print("[RaceResults] RaceResults scene ready")
	
	# Connect continue button
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
		print("[Race] Back button pressed - returning to training")
		GameManager.change_scene("res://scenes/game_flow/training.tscn")
