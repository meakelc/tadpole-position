# training.gd - Training scene script for training.tscn
extends Control

# UI elements (create these as child nodes in training.tscn)
@onready var instruction_label: Label = $VBoxContainer/InstructionLabel
@onready var croaker_stats_label: Label = $VBoxContainer/CroakerStatsLabel
@onready var upgrade_button_1: Button = $VBoxContainer/UpgradeContainer/UpgradeButton1
@onready var upgrade_button_2: Button = $VBoxContainer/UpgradeContainer/UpgradeButton2
@onready var upgrade_button_3: Button = $VBoxContainer/UpgradeContainer/UpgradeButton3
@onready var back_button: Button = $VBoxContainer/BackButton

# Training state
var training_rounds_completed := 0
const MAX_TRAINING_ROUNDS := 3

# Upgrade data structure
class Upgrade:
	var display_text: String
	var type: String  # "jump_distance", "action_delay", "stamina"
	var value: float
	var secondary_type: String = ""  # For dual upgrades
	var secondary_value: float = 0.0
	
	func _init(text: String, upgrade_type: String, upgrade_value: float, sec_type: String = "", sec_value: float = 0.0):
		display_text = text
		type = upgrade_type
		value = upgrade_value
		secondary_type = sec_type
		secondary_value = sec_value

# Current upgrade options
var current_upgrades: Array[Upgrade] = []

func _ready() -> void:
	print("[Training] Training scene ready")
	
	# Validate RunManager is available
	if not RunManager:
		print("[Training] ERROR: RunManager not found! Returning to main menu...")
		GameManager.change_scene("res://scenes/main_menu.tscn")
		return
	
	# Check if we have a Croaker, create one if not
	if not RunManager.current_croaker:
		print("[Training] No Croaker found, starting new run")
		var success = RunManager.start_new_run("Rookie Frog")
		if not success:
			print("[Training] ERROR: Failed to start new run! Returning to main menu...")
			GameManager.change_scene("res://scenes/main_menu.tscn")
			return
	
	# Set up UI
	back_button.text = "Back to Main Menu"
	back_button.pressed.connect(_on_back_pressed)
	
	# Display current stats and generate first upgrades
	_update_stats_display()
	_generate_upgrade_options()

func _update_stats_display() -> void:
	if not RunManager or not RunManager.current_croaker:
		croaker_stats_label.text = "No Croaker!"
		return
	
	var croaker = RunManager.current_croaker
	croaker_stats_label.text = "%s - Jump: %.1f | Speed: %.1f | Round: %d/%d" % [
		croaker.name,
		croaker.jump_distance,
		croaker.action_delay,
		training_rounds_completed + 1,
		MAX_TRAINING_ROUNDS
	]

# Helper method for clean button setup
func _setup_upgrade_button(button: Button, index: int, upgrade: Upgrade) -> void:
	# Disconnect if already connected (prevents "already connected" errors)
	if button.pressed.is_connected(_on_upgrade_selected):
		button.pressed.disconnect(_on_upgrade_selected)
	
	# Set up button with upgrade data
	button.text = upgrade.display_text
	button.disabled = false
	button.pressed.connect(_on_upgrade_selected.bind(index))
	
	print("[Training] Set up button %d: '%s'" % [index + 1, upgrade.display_text])

# Helper method to disable and disconnect all upgrade buttons
func _disable_all_upgrade_buttons() -> void:
	var buttons = [upgrade_button_1, upgrade_button_2, upgrade_button_3]
	
	for button in buttons:
		button.disabled = true
		if button.pressed.is_connected(_on_upgrade_selected):
			button.pressed.disconnect(_on_upgrade_selected)

func _generate_upgrade_options() -> void:
	current_upgrades.clear()
	
	# Different upgrade pools based on training round
	var upgrade_pool: Array[Upgrade] = []
	
	if training_rounds_completed == 0:
		# Round 1: Basic upgrades
		upgrade_pool = [
			Upgrade.new("Jump Boost (+2 Jump)", "jump_distance", 2.0),
			Upgrade.new("Speed Training (-0.2 Delay)", "action_delay", -0.2),
			Upgrade.new("Stamina Boost (+20)", "stamina", 20.0),
			Upgrade.new("Balanced (+1 Jump, -0.1 Delay)", "jump_distance", 1.0, "action_delay", -0.1),
		]
	elif training_rounds_completed == 1:
		# Round 2: Stronger upgrades
		upgrade_pool = [
			Upgrade.new("Power Leap (+3 Jump)", "jump_distance", 3.0),
			Upgrade.new("Quick Reflexes (-0.3 Delay)", "action_delay", -0.3),
			Upgrade.new("Trade Speed for Power (+4 Jump, +0.2 Delay)", "jump_distance", 4.0, "action_delay", 0.2),
			Upgrade.new("Endurance Training (+30 Stamina)", "stamina", 30.0),
		]
	else:
		# Round 3: Specialized upgrades
		upgrade_pool = [
			Upgrade.new("Master Jumper (+5 Jump)", "jump_distance", 5.0),
			Upgrade.new("Lightning Fast (-0.4 Delay)", "action_delay", -0.4),
			Upgrade.new("All-Rounder (+2 Jump, -0.2 Delay)", "jump_distance", 2.0, "action_delay", -0.2),
			Upgrade.new("Ultra Stamina (+50)", "stamina", 50.0),
		]
	
	# Randomly select 3 upgrades
	upgrade_pool.shuffle()
	for i in range(min(3, upgrade_pool.size())):
		current_upgrades.append(upgrade_pool[i])
	
	# Update instruction text
	instruction_label.text = "Choose an upgrade for your Croaker:"
	
	# Set up buttons using helper method
	if current_upgrades.size() > 0:
		_setup_upgrade_button(upgrade_button_1, 0, current_upgrades[0])
	else:
		upgrade_button_1.disabled = true
	
	if current_upgrades.size() > 1:
		_setup_upgrade_button(upgrade_button_2, 1, current_upgrades[1])
	else:
		upgrade_button_2.disabled = true
	
	if current_upgrades.size() > 2:
		_setup_upgrade_button(upgrade_button_3, 2, current_upgrades[2])
	else:
		upgrade_button_3.disabled = true
	
	# Focus first available button
	if current_upgrades.size() > 0:
		upgrade_button_1.grab_focus()

func _apply_upgrade_to_croaker(upgrade: Upgrade) -> void:
	"""Apply the selected upgrade to the current Croaker"""
	
	if not RunManager:
		print("[Training] ERROR: RunManager not available for upgrade application")
		return
	
	# Apply primary upgrade
	var success = RunManager.apply_upgrade(upgrade.type, upgrade.value)
	if success:
		print("[Training] Applied primary upgrade: %s %.1f" % [upgrade.type, upgrade.value])
	else:
		print("[Training] ERROR: Failed to apply primary upgrade: %s %.1f" % [upgrade.type, upgrade.value])
	
	# Apply secondary upgrade if it exists
	if upgrade.secondary_type != "":
		var secondary_success = RunManager.apply_upgrade(upgrade.secondary_type, upgrade.secondary_value)
		if secondary_success:
			print("[Training] Applied secondary upgrade: %s %.1f" % [upgrade.secondary_type, upgrade.secondary_value])
		else:
			print("[Training] ERROR: Failed to apply secondary upgrade: %s %.1f" % [upgrade.secondary_type, upgrade.secondary_value])

func _on_upgrade_selected(index: int) -> void:
	if index >= current_upgrades.size():
		print("[Training] ERROR: Invalid upgrade index: %d (only %d upgrades available)" % [index, current_upgrades.size()])
		return
	
	var selected_upgrade = current_upgrades[index]
	print("[Training] Upgrade selected: '%s'" % selected_upgrade.display_text)
	
	# Apply the upgrade to the Croaker
	_apply_upgrade_to_croaker(selected_upgrade)
	
	# Update UI feedback
	instruction_label.text = "Applied: " + selected_upgrade.display_text
	
	# Disable all buttons to prevent double-selection
	_disable_all_upgrade_buttons()
	
	# Increment training rounds
	training_rounds_completed += 1
	
	# Add a timer to proceed to next round or race
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(_proceed_after_selection)
	add_child(timer)
	timer.start()

func _proceed_after_selection() -> void:
	print("[Training] Training round %d/%d complete" % [training_rounds_completed, MAX_TRAINING_ROUNDS])
	
	if training_rounds_completed < MAX_TRAINING_ROUNDS:
		# More training rounds remaining
		print("[Training] Preparing next training round...")
		_update_stats_display()
		_generate_upgrade_options()
	else:
		# Training complete, proceed to race
		print("[Training] All training complete! Moving to race...")
		if RunManager:
			RunManager.debug_print_croaker_stats()
		GameManager.change_scene("res://scenes/game_flow/race.tscn")

func _on_back_pressed() -> void:
	print("[Training] Back button pressed - returning to main menu")
	# Clean up any connected signals before leaving
	_disable_all_upgrade_buttons()
	GameManager.change_scene("res://scenes/main_menu.tscn")

# Optional: Add debug functionality for testing
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and Input.is_action_pressed("ui_select"):
		# Debug: Skip training (Ctrl+Enter or similar combo)
		print("[Training] DEBUG: Skipping training...")
		training_rounds_completed = MAX_TRAINING_ROUNDS
		_proceed_after_selection()
	elif event.is_action_pressed("ui_cancel"):
		# Alternative back action
		_on_back_pressed()
