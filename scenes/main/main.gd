# Main.gd - Persistent Root Scene Controller
# Handles: Scene container management, overlay systems, boot sequence
# This scene stays loaded throughout the entire game lifecycle
extends Control

# ============================================================================
# NODE REFERENCES - Assigned in _ready()
# ============================================================================

# Scene management
@onready var scene_container: Control = $SceneContainer

# UI Overlays
@onready var ui_overlays: CanvasLayer = $UIOverlays
@onready var loading_overlay: Control = $UIOverlays/LoadingOverlay
@onready var loading_background: ColorRect = $UIOverlays/LoadingOverlay/LoadingBackground
@onready var loading_spinner: AnimationPlayer = $UIOverlays/LoadingOverlay/LoadingSpinner

@onready var pause_overlay: Control = $UIOverlays/PauseOverlay
@onready var pause_menu: VBoxContainer = $UIOverlays/PauseOverlay/PauseMenu
@onready var resume_button: Button = $UIOverlays/PauseOverlay/PauseMenu/ResumeButton
@onready var settings_button: Button = $UIOverlays/PauseOverlay/PauseMenu/SettingsButton
@onready var quit_button: Button = $UIOverlays/PauseOverlay/PauseMenu/QuitButton

@onready var toast_container: VBoxContainer = $UIOverlays/ToastContainer

# Debug system
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var debug_panel: Control = $DebugOverlay/DebugPanel
@onready var state_label: Label = $DebugOverlay/DebugPanel/DebugInfo/StateLabel
@onready var performance_label: Label = $DebugOverlay/DebugPanel/DebugInfo/PerformanceLabel
@onready var croaker_label: Label = $DebugOverlay/DebugPanel/DebugInfo/CroakerLabel

# Audio management
@onready var audio_manager: Node = $AudioManager
@onready var music_player: AudioStreamPlayer = $AudioManager/MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $AudioManager/SFXPlayer
@onready var ui_player: AudioStreamPlayer = $AudioManager/UIPlayer

# ============================================================================
# CONSTANTS & CONFIGURATION
# ============================================================================

const DEBUG_ENABLED := true
const TOAST_DURATION := 3.0
const LOADING_MIN_DISPLAY_TIME := 0.5

# Toast notification settings
const MAX_TOASTS := 5
const TOAST_FADE_SPEED := 2.0

# ============================================================================
# VARIABLES
# ============================================================================

# State tracking
var current_scene_instance: Node = null
var is_loading_visible: bool = false
var is_paused_by_user: bool = false
var boot_complete: bool = false

# Performance tracking
var frame_count: int = 0
var fps_update_timer: float = 0.0
var current_fps: float = 60.0

# Toast system
var active_toasts: Array[Control] = []

# ============================================================================
# INITIALIZATION & BOOT SEQUENCE
# ============================================================================

func _ready() -> void:
	print("[Main] Starting boot sequence...")
	
	# Set up as persistent root
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	# Configure initial UI state
	_setup_initial_ui_state()
	
	# Connect signals
	_connect_signals()
	
	# Set up input handling
	_setup_input_handling()
	
	# Start boot sequence
	await _perform_boot_sequence()
	
	print("[Main] Boot complete - game ready")

func _setup_initial_ui_state() -> void:
	"""Configure initial visibility and settings for UI elements"""
	# Hide overlays initially
	loading_overlay.visible = false
	pause_overlay.visible = false
	debug_overlay.visible = DEBUG_ENABLED
	
	# Configure loading overlay
	loading_background.color = Color(0, 0, 0, 0.8)
	loading_background.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Configure pause overlay
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Set up scene container
	scene_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_container.mouse_filter = Control.MOUSE_FILTER_PASS

func _connect_signals() -> void:
	"""Connect to manager signals and UI events"""
	# Pause menu buttons
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Debug buttons (if they exist)
	_connect_debug_buttons()
	
	# Connect to singletons when they're ready (deferred)
	call_deferred("_connect_to_singletons")

func _connect_to_singletons() -> void:
	"""Connect to singleton signals once they're available"""
	# Wait for GameManager to be ready
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		game_manager.scene_transition_started.connect(_on_scene_transition_started)
		game_manager.scene_transition_finished.connect(_on_scene_transition_finished)
		game_manager.fade_out_finished.connect(_on_fade_out_finished)
		game_manager.fade_in_finished.connect(_on_fade_in_finished)
		game_manager.game_state_changed.connect(_on_game_state_changed)
		print("[Main] Connected to GameManager signals")
	else:
		print("[Main] GameManager not yet available, will retry...")
		# Retry connection after a short delay
		get_tree().create_timer(0.1).timeout.connect(_connect_to_singletons)

func _connect_debug_buttons() -> void:
	"""Connect debug shortcut buttons if they exist"""
	var debug_buttons = $DebugOverlay/DebugPanel/DebugInfo/DebugButtons
	if debug_buttons:
		var scene_button1 = debug_buttons.get_node_or_null("SceneButton1")
		var scene_button2 = debug_buttons.get_node_or_null("SceneButton2") 
		var scene_button3 = debug_buttons.get_node_or_null("SceneButton3")
		
		if scene_button1:
			scene_button1.text = "Menu"
			scene_button1.pressed.connect(_debug_go_to_menu)
		if scene_button2:
			scene_button2.text = "Paddock"
			scene_button2.pressed.connect(_debug_go_to_paddock)
		if scene_button3:
			scene_button3.text = "Run"
			scene_button3.pressed.connect(_debug_go_to_run)

func _debug_go_to_menu() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").transition_to_scene("main_menu")

func _debug_go_to_paddock() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").transition_to_scene("lily_paddock")

func _debug_go_to_run() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").transition_to_scene("run_hub")

func _setup_input_handling() -> void:
	"""Configure input handling for the root scene"""
	# Ensure we can receive input events
	set_process_input(true)
	set_process_unhandled_input(true)

func _perform_boot_sequence() -> void:
	"""Handle initial game startup"""
	show_loading_overlay("Initializing...")
	
	# Simulate boot time for any heavy initialization
	await get_tree().create_timer(0.5).timeout
	
	# Initialize audio system
	_initialize_audio_system()
	
	# Update loading text
	update_loading_text("Loading game data...")
	await get_tree().create_timer(0.3).timeout
	
	# Any other initialization
	update_loading_text("Starting game...")
	await get_tree().create_timer(0.2).timeout
	
	hide_loading_overlay()
	boot_complete = true
	
	# Let GameManager know we're ready (if available)
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.current_state == game_manager.GameState.STARTUP:
			show_toast("Welcome to TadPole Position!", 2.0)

# ============================================================================
# SCENE CONTAINER MANAGEMENT
# ============================================================================

func set_scene_instance(scene_instance: Node) -> void:
	"""Replace the current scene instance in the container"""
	# Clear existing scene
	if current_scene_instance and is_instance_valid(current_scene_instance):
		current_scene_instance.queue_free()
	
	# Add new scene
	if scene_instance:
		scene_container.add_child(scene_instance)
		current_scene_instance = scene_instance
		print("[Main] Scene instance set: %s" % scene_instance.name)

func get_current_scene() -> Node:
	"""Get the currently loaded scene instance"""
	return current_scene_instance

func clear_scene_container() -> void:
	"""Remove current scene from container"""
	if current_scene_instance and is_instance_valid(current_scene_instance):
		current_scene_instance.queue_free()
		current_scene_instance = null

# ============================================================================
# LOADING OVERLAY SYSTEM
# ============================================================================

func show_loading_overlay(text: String = "Loading...") -> void:
	"""Display loading overlay with optional text"""
	if is_loading_visible:
		return
	
	loading_overlay.visible = true
	is_loading_visible = true
	
	# Start spinner animation if available
	if loading_spinner and loading_spinner.has_animation("spin"):
		loading_spinner.play("spin")
	
	print("[Main] Loading overlay shown: %s" % text)

func hide_loading_overlay() -> void:
	"""Hide the loading overlay"""
	if not is_loading_visible:
		return
	
	loading_overlay.visible = false
	is_loading_visible = false
	
	# Stop spinner animation
	if loading_spinner:
		loading_spinner.stop()
	
	print("[Main] Loading overlay hidden")

func update_loading_text(text: String) -> void:
	"""Update loading overlay text if label exists"""
	var loading_label = loading_overlay.get_node_or_null("LoadingLabel")
	if loading_label and loading_label is Label:
		loading_label.text = text

# ============================================================================
# PAUSE SYSTEM
# ============================================================================

func toggle_pause() -> void:
	"""Toggle pause state"""
	if is_paused_by_user:
		resume_game()
	else:
		pause_game()

func pause_game() -> void:
	"""Pause the game and show pause menu"""
	if is_paused_by_user:
		return
		
	is_paused_by_user = true
	pause_overlay.visible = true
	get_tree().paused = true
	
	# Focus resume button for controller support
	resume_button.grab_focus()
	
	print("[Main] Game paused by user")

func resume_game() -> void:
	"""Resume the game and hide pause menu"""
	if not is_paused_by_user:
		return
		
	is_paused_by_user = false
	pause_overlay.visible = false
	get_tree().paused = false
	
	print("[Main] Game resumed")

# ============================================================================
# TOAST NOTIFICATION SYSTEM
# ============================================================================

func show_toast(message: String, duration: float = TOAST_DURATION) -> void:
	"""Display a temporary toast notification"""
	# Remove oldest toast if at limit
	if active_toasts.size() >= MAX_TOASTS:
		_remove_toast(active_toasts[0])
	
	# Create toast UI
	var toast = _create_toast_ui(message)
	
	# Add to container and track
	toast_container.add_child(toast)
	active_toasts.append(toast)
	
	# Fade in
	_animate_toast_in(toast)
	
	# Auto-remove after duration
	get_tree().create_timer(duration).timeout.connect(
		func(): _remove_toast(toast)
	)

func _create_toast_ui(message: String) -> Control:
	"""Create the UI for a toast notification"""
	var toast = PanelContainer.new()
	toast.modulate.a = 0.0  # Start invisible for fade-in
	
	# Style the toast
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.8, 1.0, 0.8)
	
	toast.add_theme_stylebox_override("panel", style)
	
	# Add label
	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(label)
	
	return toast

func _animate_toast_in(toast: Control) -> void:
	"""Animate toast fade-in"""
	var tween = create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	tween.tween_property(toast, "modulate:a", 1.0, TOAST_DURATION - 0.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)

func _remove_toast(toast: Control) -> void:
	"""Remove a toast from the display"""
	if toast in active_toasts:
		active_toasts.erase(toast)
	
	if is_instance_valid(toast):
		toast.queue_free()

# ============================================================================
# AUDIO MANAGEMENT
# ============================================================================

func _initialize_audio_system() -> void:
	"""Set up the audio players"""
	# Configure audio players
	music_player.bus = "Music"
	sfx_player.bus = "SFX"
	ui_player.bus = "UI"
	
	# Set reasonable volumes
	music_player.volume_db = -10
	sfx_player.volume_db = -5
	ui_player.volume_db = -8
	
	print("[Main] Audio system initialized")

func play_ui_sound(_sound_name: String) -> void:
	"""Play a UI sound effect"""
	# TODO: Load and play UI sound based on name
	# For now, placeholder
	pass

# ============================================================================
# DEBUG SYSTEM
# ============================================================================

func toggle_debug_overlay() -> void:
	"""Toggle debug information display"""
	if not DEBUG_ENABLED:
		return
		
	debug_overlay.visible = !debug_overlay.visible
	print("[Main] Debug overlay toggled: %s" % debug_overlay.visible)

func _update_debug_info() -> void:
	"""Update debug information display"""
	if not DEBUG_ENABLED or not debug_overlay.visible:
		return
	
	# Update FPS
	fps_update_timer += get_process_delta_time()
	frame_count += 1
	
	if fps_update_timer >= 1.0:  # Update every second
		current_fps = frame_count / fps_update_timer
		frame_count = 0
		fps_update_timer = 0.0
	
	# Update labels
	if state_label:
		var state_name = "Unknown"
		if has_node("/root/GameManager"):
			var game_manager = get_node("/root/GameManager")
			state_name = game_manager.GameState.keys()[game_manager.current_state]
		state_label.text = "State: %s" % state_name
	
	if performance_label:
		var memory_mb = OS.get_static_memory_peak_usage() / 1048576.0
		performance_label.text = "FPS: %.1f\nMemory: %.1f MB" % [
			current_fps,
			memory_mb
		]
	
	if croaker_label:
		var croaker_info = "No Croaker"
		var total_count = 0
		
		if has_node("/root/CroakerManager"):
			var croaker_manager = get_node("/root/CroakerManager")
			var run_croaker = croaker_manager.get_run_croaker()
			if run_croaker:
				croaker_info = run_croaker.croaker_name
			total_count = croaker_manager.get_croaker_count()
		
		croaker_label.text = "Active: %s\nTotal: %d" % [croaker_info, total_count]

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	"""Handle global input events"""
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_ESCAPE:
			if is_paused_by_user:
				resume_game()
			else:
				pause_game()
		
		KEY_F12:
			toggle_debug_overlay()
		
		# Debug shortcuts (only in debug builds)
		KEY_F1:
			if DEBUG_ENABLED and has_node("/root/GameManager"):
				get_node("/root/GameManager").transition_to_scene("main_menu")
		KEY_F2:
			if DEBUG_ENABLED and has_node("/root/GameManager"):
				get_node("/root/GameManager").transition_to_scene("lily_paddock")
		KEY_F3:
			if DEBUG_ENABLED and has_node("/root/GameManager"):
				get_node("/root/GameManager").transition_to_scene("run_hub")

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_scene_transition_started(_from_scene: String, to_scene: String) -> void:
	"""Handle scene transition start"""
	show_loading_overlay("Loading %s..." % to_scene.replace("_", " ").capitalize())

func _on_scene_transition_finished(scene_name: String) -> void:
	"""Handle scene transition completion"""
	hide_loading_overlay()
	show_toast("Entered %s" % scene_name.replace("_", " ").capitalize(), 1.5)

func _on_fade_out_finished() -> void:
	"""Handle fade out completion"""
	# Additional logic if needed during fade out
	pass

func _on_fade_in_finished() -> void:
	"""Handle fade in completion"""
	# Additional logic if needed during fade in
	pass

func _on_game_state_changed(old_state, new_state) -> void:
	"""Handle game state changes"""
	if not has_node("/root/GameManager"):
		return
		
	var game_manager = get_node("/root/GameManager")
	print("[Main] Game state changed: %s -> %s" % [
		game_manager.GameState.keys()[old_state],
		game_manager.GameState.keys()[new_state]
	])
	
	# Handle state-specific UI changes
	match new_state:
		game_manager.GameState.PAUSED:
			if not is_paused_by_user:  # Only if not already paused by user
				pause_game()
		game_manager.GameState.MAIN_MENU, game_manager.GameState.LILY_PADDOCK:
			if is_paused_by_user:  # Resume if user-paused
				resume_game()

# Pause menu button handlers
func _on_resume_pressed() -> void:
	"""Handle resume button press"""
	play_ui_sound("click")
	resume_game()

func _on_settings_pressed() -> void:
	"""Handle settings button press"""
	play_ui_sound("click")
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").push_modal_scene("settings")

func _on_quit_pressed() -> void:
	"""Handle quit button press"""
	play_ui_sound("click")
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").quit_game()

# ============================================================================
# PROCESS UPDATES
# ============================================================================

func _process(_delta: float) -> void:
	"""Update debug info and other per-frame systems"""
	if DEBUG_ENABLED:
		_update_debug_info()

# ============================================================================
# PUBLIC API
# ============================================================================

# Scene Management:
# - set_scene_instance(scene_instance: Node)
# - get_current_scene() -> Node
# - clear_scene_container()

# Loading System:
# - show_loading_overlay(text: String = "Loading...")
# - hide_loading_overlay()
# - update_loading_text(text: String)

# Pause System:
# - toggle_pause()
# - pause_game()
# - resume_game()

# Notifications:
# - show_toast(message: String, duration: float = TOAST_DURATION)

# Debug:
# - toggle_debug_overlay()

# Audio:
# - play_ui_sound(sound_name: String)
