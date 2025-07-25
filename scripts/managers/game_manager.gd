# GameManager.gd - AutoLoad Singleton
# Handles: Scene management, transitions, global game state, debug systems
# Architecture: Central coordinator that manages high-level game flow
# This is NOT run-specific logic - that belongs in RunManager

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

# Scene transition signals
signal scene_transition_started(from_scene: String, to_scene: String)
signal scene_transition_finished(scene_name: String)
signal fade_in_finished
signal fade_out_finished

# Game state signals  
signal game_state_changed(old_state: GameState, new_state: GameState)

# ============================================================================
# ENUMS & CONSTANTS
# ============================================================================

enum GameState {
	STARTUP,        # Initial loading/splash
	MAIN_MENU,      # Main menu navigation
	LILY_PADDOCK,   # Meta progression hub
	IN_RUN,         # Active run (training/racing) - RunManager takes over
	PAUSED,         # Game paused
	SETTINGS,       # Settings menu
	QUITTING        # Shutdown sequence
}

# Scene paths - centralized for easy maintenance
const SCENES := {
	"main_menu": "res://scenes/ui/MainMenu.tscn",
	"lily_paddock": "res://scenes/game_flow/LilyPaddock.tscn", 
	"run_hub": "res://scenes/game_flow/RunHub.tscn",
	"training_stage": "res://scenes/game_flow/TrainingStage.tscn",
	"race_screen": "res://scenes/game_flow/RaceScreen.tscn",
	"settings": "res://scenes/ui/Settings.tscn"
}

# Debug flags - easily configurable
const DEBUG_SCENE_TRANSITIONS := true
const DEBUG_STATE_CHANGES := true
const DEBUG_PERFORMANCE := true
const ENABLE_DEV_SHORTCUTS := true

# Transition settings
const FADE_DURATION := 0.3
const MIN_SCENE_DISPLAY_TIME := 0.5  # Prevent jarring quick transitions

# ============================================================================
# VARIABLES
# ============================================================================

# Core state
var current_state: GameState = GameState.STARTUP
var previous_state: GameState = GameState.STARTUP
var current_scene_name: String = ""
var is_transitioning: bool = false

# Scene management
var _scene_stack: Array[String] = []  # For modal overlays
var _transition_queue: Array[Dictionary] = []  # Queue transitions if needed
var _scene_change_time: float = 0.0

# UI elements for transitions
var _fade_overlay: ColorRect
var _loading_label: Label

# Performance tracking (debug)
var _frame_times: Array[float] = []
var _avg_fps: float = 60.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_debug_log("GameManager initializing...")
	
	# Set up process mode to handle pausing
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	# Initialize UI elements
	_setup_fade_overlay()
	_setup_debug_ui()
	
	# Connect to tree signals
	get_tree().connect("node_added", _on_node_added)
	get_tree().connect("node_removed", _on_node_removed)
	
	# Initial state setup
	_change_state(GameState.STARTUP)
	
	# Load initial scene after brief delay
	await get_tree().create_timer(0.1).timeout
	transition_to_scene("main_menu")
	
	_debug_log("GameManager ready")

func _setup_fade_overlay() -> void:
	"""Creates fade overlay for smooth scene transitions"""
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color.BLACK
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Full screen coverage
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Highest z-order for transitions
	_fade_overlay.z_index = 1000
	_fade_overlay.visible = false
	
	# Add to scene tree (persistent across scene changes)
	get_tree().root.add_child(_fade_overlay)

func _setup_debug_ui() -> void:
	"""Sets up debug information display"""
	if not DEBUG_PERFORMANCE:
		return
		
	# Create debug label
	_loading_label = Label.new()
	_loading_label.text = "GameManager Debug"
	_loading_label.position = Vector2(10, 10)
	_loading_label.z_index = 999
	_loading_label.modulate = Color.YELLOW
	
	get_tree().root.add_child(_loading_label)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: GameState) -> void:
	"""Changes game state with proper validation and signals"""
	if current_state == new_state:
		return
		
	var old_state = current_state
	previous_state = current_state
	current_state = new_state
	
	_debug_log("State change: %s -> %s" % [
		GameState.keys()[old_state], 
		GameState.keys()[new_state]
	])
	
	# Handle state-specific logic
	match new_state:
		GameState.IN_RUN:
			# RunManager takes control during runs
			_debug_log("Entering run state - RunManager has control")
			
		GameState.PAUSED:
			get_tree().paused = true
			
		GameState.MAIN_MENU, GameState.LILY_PADDOCK:
			get_tree().paused = false
			
		GameState.QUITTING:
			_handle_quit_sequence()
	
	emit_signal("game_state_changed", old_state, new_state)

func get_current_state() -> GameState:
	"""Public getter for current state"""
	return current_state

func is_in_state(state: GameState) -> bool:
	"""Check if currently in specific state"""
	return current_state == state

func can_transition_to_scene(scene_name: String) -> bool:
	"""Validates if scene transition is allowed in current state"""
	if is_transitioning:
		_debug_log("Transition blocked - already transitioning")
		return false
		
	if not SCENES.has(scene_name):
		_debug_log("Transition blocked - unknown scene: %s" % scene_name)
		return false
		
	# State-specific restrictions
	match current_state:
		GameState.QUITTING:
			return false
		GameState.IN_RUN:
			# Only allow run-related scenes during runs
			var allowed_run_scenes = ["training_stage", "race_screen", "run_hub"]
			return scene_name in allowed_run_scenes
		_:
			return true

# ============================================================================
# SCENE MANAGEMENT
# ============================================================================

func transition_to_scene(scene_name: String, transition_data: Dictionary = {}) -> void:
	"""Main scene transition function with fade effect"""
	if not can_transition_to_scene(scene_name):
		_debug_log("Scene transition denied: %s" % scene_name)
		return
		
	_debug_log("Starting transition to: %s" % scene_name)
	
	is_transitioning = true
	emit_signal("scene_transition_started", current_scene_name, scene_name)
	
	# Queue transition if one is already in progress
	if _is_tween_active():
		_transition_queue.append({
			"scene_name": scene_name,
			"data": transition_data
		})
		return
	
	# Start fade out
	await _fade_out()
	
	# Change scene
	var success = await _change_scene(scene_name, transition_data)
	
	if success:
		# Fade in new scene
		await _fade_in()
		current_scene_name = scene_name
		emit_signal("scene_transition_finished", scene_name)
	else:
		# Fade back in on failure
		await _fade_in()
		_debug_log("Scene transition failed, staying in current scene")
	
	is_transitioning = false
	_scene_change_time = Time.get_time_dict_from_system()["unix"]
	
	# Process queued transitions
	_process_transition_queue()

func _fade_out() -> void:
	"""Fade to black"""
	_fade_overlay.visible = true
	_fade_overlay.modulate.a = 0.0
	
	var tween = create_tween()
	var tween_property = tween.tween_property(
		_fade_overlay, 
		"modulate:a", 
		1.0, 
		FADE_DURATION
	)
	tween_property.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	emit_signal("fade_out_finished")

func _fade_in() -> void:
	"""Fade from black"""
	var tween = create_tween()
	var tween_property = tween.tween_property(
		_fade_overlay, 
		"modulate:a", 
		0.0, 
		FADE_DURATION
	)
	tween_property.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	_fade_overlay.visible = false
	emit_signal("fade_in_finished")

func _is_tween_active() -> bool:
	"""Check if any transition tween is currently running"""
	# In Godot 4, we create tweens on-demand, so we track via is_transitioning flag
	return is_transitioning

func _change_scene(scene_name: String, transition_data: Dictionary) -> bool:
	"""Actually changes the scene"""
	if not SCENES.has(scene_name):
		_debug_log("ERROR: Unknown scene: %s" % scene_name)
		return false
	
	var scene_path = SCENES[scene_name]
	
	# Validate scene file exists
	if not ResourceLoader.exists(scene_path):
		_debug_log("ERROR: Scene file not found: %s" % scene_path)
		return false
	
	# Load new scene
	var new_scene = load(scene_path)
	if not new_scene:
		_debug_log("ERROR: Failed to load scene: %s" % scene_path)
		return false
	
	# Change to new scene
	var result = get_tree().change_scene_to_packed(new_scene)
	if result != OK:
		_debug_log("ERROR: Failed to change scene, error code: %d" % result)
		return false
	
	# Update state based on scene
	_update_state_for_scene(scene_name)
	
	# Wait one frame for scene to initialize
	await get_tree().process_frame
	
	# Pass transition data to new scene if it accepts it
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("on_scene_entered"):
		current_scene.on_scene_entered(transition_data)
	
	_debug_log("Successfully changed to scene: %s" % scene_name)
	return true

func _update_state_for_scene(scene_name: String) -> void:
	"""Updates game state based on the loaded scene"""
	match scene_name:
		"main_menu":
			_change_state(GameState.MAIN_MENU)
		"lily_paddock":
			_change_state(GameState.LILY_PADDOCK)
		"run_hub", "training_stage", "race_screen":
			_change_state(GameState.IN_RUN)
		"settings":
			_change_state(GameState.SETTINGS)

func _process_transition_queue() -> void:
	"""Processes any queued scene transitions"""
	if _transition_queue.is_empty():
		return
		
	var next_transition = _transition_queue.pop_front()
	transition_to_scene(next_transition.scene_name, next_transition.data)

# ============================================================================
# MODAL SCENE STACK (for overlays like settings)
# ============================================================================

func push_modal_scene(scene_name: String) -> void:
	"""Pushes a modal scene onto the stack (like settings over main menu)"""
	_scene_stack.push_back(current_scene_name)
	transition_to_scene(scene_name)

func pop_modal_scene() -> void:
	"""Returns to the previous scene in the stack"""
	if _scene_stack.is_empty():
		_debug_log("WARNING: No scene to pop, going to main menu")
		transition_to_scene("main_menu")
		return
		
	var previous_scene = _scene_stack.pop_back()
	transition_to_scene(previous_scene)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func quit_game() -> void:
	"""Graceful game shutdown"""
	_debug_log("Quit requested")
	_change_state(GameState.QUITTING)

func _handle_quit_sequence() -> void:
	"""Handles cleanup before quitting"""
	_debug_log("Starting quit sequence...")
	
	# Save any necessary data here
	# Notify other systems of shutdown
	
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

# ============================================================================
# DEBUG & DEVELOPMENT
# ============================================================================

func _input(event: InputEvent) -> void:
	"""Handle debug shortcuts"""
	if not ENABLE_DEV_SHORTCUTS:
		return
		
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				transition_to_scene("main_menu")
			KEY_F2:
				transition_to_scene("lily_paddock")
			KEY_F3:
				transition_to_scene("run_hub")
			KEY_F12:
				_toggle_debug_info()

func _toggle_debug_info() -> void:
	"""Toggles debug information display"""
	if _loading_label:
		_loading_label.visible = !_loading_label.visible

func _process(delta: float) -> void:
	"""Update debug information"""
	if not DEBUG_PERFORMANCE or not _loading_label or not _loading_label.visible:
		return
		
	# Track performance
	_frame_times.append(delta)
	if _frame_times.size() > 60:  # Keep last 60 frames
		_frame_times.pop_front()
		
	if _frame_times.size() > 0:
		var avg_frame_time = _frame_times.reduce(func(a, b): return a + b) / _frame_times.size()
		_avg_fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 60.0
	
	# Update debug display
	_loading_label.text = "GameManager Debug\nFPS: %.1f\nState: %s\nScene: %s\nTransitioning: %s" % [
		_avg_fps,
		GameState.keys()[current_state],
		current_scene_name,
		"Yes" if is_transitioning else "No"
	]

func _debug_log(message: String) -> void:
	"""Centralized debug logging"""
	if DEBUG_SCENE_TRANSITIONS or DEBUG_STATE_CHANGES:
		print("[GameManager] %s" % message)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_node_added(node: Node) -> void:
	"""Called when any node is added to the scene tree"""
	if DEBUG_SCENE_TRANSITIONS and node == get_tree().current_scene:
		_debug_log("New scene added: %s" % node.name)

func _on_node_removed(node: Node) -> void:
	"""Called when any node is removed from the scene tree"""
	if DEBUG_SCENE_TRANSITIONS and node.name.begins_with("@"):
		# Likely a scene being removed
		_debug_log("Scene removed: %s" % node.name)

# ============================================================================
# PUBLIC API SUMMARY
# ============================================================================

# Primary Functions:
# - transition_to_scene(scene_name: String, transition_data: Dictionary = {})
# - push_modal_scene(scene_name: String) / pop_modal_scene()
# - get_current_state() -> GameState
# - is_in_state(state: GameState) -> bool
# - quit_game()

# Key Signals:
# - scene_transition_started(from_scene, to_scene)
# - scene_transition_finished(scene_name)
# - game_state_changed(old_state, new_state)

# Architecture Notes:
# - AutoLoad singleton - always available via GameManager
# - Handles high-level flow, RunManager handles run-specific logic
# - Fade transitions prevent jarring scene changes
# - Debug shortcuts (F1-F3) for rapid testing
# - Performance tracking for optimization
# - Graceful error handling with fallbacks
