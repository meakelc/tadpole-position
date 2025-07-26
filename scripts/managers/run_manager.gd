# run_manager.gd - AutoLoad Singleton
# Orchestrates the complete run flow from training through elimination
# Core Loop: Training → Race → Upgrade → Repeat (with elimination stakes)
extends Node

# Run state machine
enum RunState {
	MENU,        # Croaker selection and run setup
	TRAINING,    # Pre-run training stage with upgrade selections
	RACING,      # Individual race in progress
	ELIMINATION, # Post-race elimination check and progression
	COMPLETE     # Run finished (win or elimination)
}

# State change signals - follow snake_case_verb pattern
signal state_changed(new_state: RunState, old_state: RunState)
signal run_started(croaker: Croaker)
signal training_completed(final_croaker: Croaker)
signal race_requested(croaker: Croaker, race_config: Dictionary)
signal race_completed(results: Dictionary)
signal elimination_occurred(eliminated_croakers: Array)
signal run_completed(final_result: Dictionary)

# Run configuration
const MAX_TRAINING_ROUNDS := 5
const RACES_PER_ROUND := 2
const ELIMINATION_ROUNDS := 3  # Simplified: 8→6→4→2 instead of 16→12→8→4

# Current run state
var current_state: RunState = RunState.MENU
var current_croaker: Croaker
var current_round: int = 0
var current_race_in_round: int = 0
var race_results: Array[Dictionary] = []
var remaining_opponents: Array[Croaker] = []

# Run statistics tracking
var training_selections: Array[String] = []
var total_races_completed: int = 0
var best_race_position: int = 99
var warts_earned: Array = []

func _ready() -> void:
	# Connect to other manager signals when they're implemented
	# TODO: Connect to RaceSimulator.race_finished
	# TODO: Connect to WartSystem.wart_selected
	pass

# =============================================================================
# Public Interface - Main Run Flow Control
# =============================================================================

## Start a new run with the selected Croaker
func start_run(croaker: Croaker) -> void:
	if current_state != RunState.MENU:
		push_warning("Cannot start run - not in MENU state")
		return
	
	# TODO: Initialize run state
	# TODO: Reset race results and statistics
	# TODO: Generate opponent pool
	_change_state(RunState.TRAINING)
	emit_signal("run_started", croaker)

## Request transition to next appropriate state
func advance_run() -> void:
	match current_state:
		RunState.TRAINING:
			_complete_training()
		RunState.RACING:
			push_warning("Cannot advance from RACING - wait for race completion")
		RunState.ELIMINATION:
			_check_elimination_and_advance()
		RunState.COMPLETE:
			_return_to_menu()
		RunState.MENU:
			push_warning("Cannot advance from MENU - start a run first")

## Force return to menu (for quit/restart scenarios)
func return_to_menu() -> void:
	# TODO: Clean up current run state
	# TODO: Save any persistent progress
	_change_state(RunState.MENU)

# =============================================================================
# Training Stage Methods
# =============================================================================

## Complete training stage and move to first race
func _complete_training() -> void:
	# TODO: Finalize training selections
	# TODO: Apply all training bonuses to croaker
	# TODO: Set up first race
	emit_signal("training_completed", current_croaker)
	_setup_next_race()

## Apply a training selection to the current croaker
func apply_training_selection(upgrade_id: String) -> void:
	if current_state != RunState.TRAINING:
		push_warning("Can only apply training during TRAINING state")
		return
	
	# TODO: Apply upgrade to current_croaker
	# TODO: Track selection for statistics
	training_selections.append(upgrade_id)

# =============================================================================
# Racing Stage Methods
# =============================================================================

## Set up and start the next race in the sequence
func _setup_next_race() -> void:
	# TODO: Determine race configuration based on current round/race
	# TODO: Select appropriate opponents
	# TODO: Generate race parameters
	
	var race_config = {
		"round": current_round,
		"race_in_round": current_race_in_round,
		"is_elimination_race": current_race_in_round == RACES_PER_ROUND,
		"opponents": []  # TODO: Fill with appropriate opponents
	}
	
	_change_state(RunState.RACING)
	emit_signal("race_requested", current_croaker, race_config)

## Handle completion of a race
func _on_race_completed(results: Dictionary) -> void:
	if current_state != RunState.RACING:
		push_warning("Received race completion while not in RACING state")
		return
	
	# TODO: Process race results
	# TODO: Update statistics
	# TODO: Award warts based on placement
	
	race_results.append(results)
	total_races_completed += 1
	
	# Update best position if improved
	var player_position = results.get("player_position", 99)
	if player_position < best_race_position:
		best_race_position = player_position
	
	emit_signal("race_completed", results)
	_change_state(RunState.ELIMINATION)

# =============================================================================
# Elimination Stage Methods
# =============================================================================

## Check for elimination and advance to next stage
func _check_elimination_and_advance() -> void:
	var is_elimination_race = (current_race_in_round == RACES_PER_ROUND)
	
	if is_elimination_race:
		var eliminated = _process_elimination()
		if eliminated.has(current_croaker):
			# Player eliminated - end run
			_complete_run(false)
			return
		else:
			# Advance to next round
			current_round += 1
			current_race_in_round = 0
			emit_signal("elimination_occurred", eliminated)
	
	# Check if this was the final race
	if _is_final_race():
		var won_championship = _check_championship_victory()
		_complete_run(won_championship)
	else:
		# Advance to next race
		current_race_in_round += 1
		_setup_next_race()

## Process elimination logic and return eliminated croakers
func _process_elimination() -> Array[Croaker]:
	# TODO: Implement elimination based on recent race performance
	# TODO: Grid positioning logic
	# TODO: Bottom N elimination
	return []  # Placeholder

## Check if player won the championship
func _check_championship_victory() -> bool:
	# TODO: Check if player placed 1st in final race
	return false  # Placeholder

## Check if this is the final race of the tournament
func _is_final_race() -> bool:
	return current_round >= ELIMINATION_ROUNDS and current_race_in_round >= RACES_PER_ROUND

# =============================================================================
# Run Completion Methods
# =============================================================================

## Complete the run with win/loss result
func _complete_run(victory: bool) -> void:
	var final_result = {
		"victory": victory,
		"rounds_completed": current_round,
		"total_races": total_races_completed,
		"best_position": best_race_position,
		"warts_earned": warts_earned.size(),
		"final_croaker": current_croaker
	}
	
	# TODO: Award trophies/unlocks for victory
	# TODO: Update meta progression
	# TODO: Add croaker to breeding legacy
	
	emit_signal("run_completed", final_result)
	_change_state(RunState.COMPLETE)

## Clean up and return to menu
func _return_to_menu() -> void:
	# TODO: Reset all run variables
	# TODO: Clear temporary state
	current_croaker = null
	current_round = 0
	current_race_in_round = 0
	race_results.clear()
	training_selections.clear()
	warts_earned.clear()
	total_races_completed = 0
	best_race_position = 99
	
	_change_state(RunState.MENU)

# =============================================================================
# State Management
# =============================================================================

## Internal state change with validation and signals
func _change_state(new_state: RunState) -> void:
	var old_state = current_state
	
	# Validate state transition
	if not _is_valid_transition(old_state, new_state):
		push_error("Invalid state transition: %s -> %s" % [
			RunState.keys()[old_state], 
			RunState.keys()[new_state]
		])
		return
	
	current_state = new_state
	emit_signal("state_changed", new_state, old_state)
	
	# Debug logging
	if OS.is_debug_build():
		print("[RunManager] State: %s -> %s" % [
			RunState.keys()[old_state], 
			RunState.keys()[new_state]
		])

## Validate if state transition is allowed
func _is_valid_transition(from: RunState, to: RunState) -> bool:
	# TODO: Implement proper state transition validation
	# For now, allow most transitions for flexibility during development
	match from:
		RunState.MENU:
			return to == RunState.TRAINING
		RunState.TRAINING:
			return to == RunState.RACING or to == RunState.MENU
		RunState.RACING:
			return to == RunState.ELIMINATION or to == RunState.MENU
		RunState.ELIMINATION:
			return to in [RunState.RACING, RunState.COMPLETE, RunState.MENU]
		RunState.COMPLETE:
			return to == RunState.MENU
		_:
			return false

# =============================================================================
# Query Methods - For UI and other systems
# =============================================================================

## Get current run progress information
func get_run_progress() -> Dictionary:
	return {
		"state": current_state,
		"round": current_round,
		"race_in_round": current_race_in_round,
		"total_races_completed": total_races_completed,
		"best_position": best_race_position,
		"training_rounds_completed": training_selections.size()
	}

## Check if currently in a race
func is_racing() -> bool:
	return current_state == RunState.RACING

## Check if run is active (not in menu or complete)
func is_run_active() -> bool:
	return current_state not in [RunState.MENU, RunState.COMPLETE]

## Get remaining races in current round
func get_races_remaining_in_round() -> int:
	return RACES_PER_ROUND - current_race_in_round

## Get total rounds remaining
func get_rounds_remaining() -> int:
	return ELIMINATION_ROUNDS - current_round

# =============================================================================
# Debug Methods
# =============================================================================

## Print current run state for debugging
func debug_print_state() -> void:
	if not OS.is_debug_build():
		return
	
	print("=== RunManager Debug State ===")
	print("Current State: ", RunState.keys()[current_state])
	print("Round: %d/%d" % [current_round, ELIMINATION_ROUNDS])
	print("Race in Round: %d/%d" % [current_race_in_round, RACES_PER_ROUND])
	print("Total Races: ", total_races_completed)
	print("Best Position: ", best_race_position)
	print("Training Selections: ", training_selections.size())
	print("Warts Earned: ", warts_earned.size())
	print("==============================")
