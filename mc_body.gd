## A grid-locked moving body.
##
## Used for anything that occupies a single cell on the level's
## [TileMapLayer] and moves one tile at a time — currently both the player
## robot and the goal marker in a level scene.
##
## The body is a sibling of its [TileMapLayer]: it resolves the tilemap via
## [code]$"../RoadTileMapLayer"[/code].
## Rename or reparent either node will break this class.
##
## Two ways to move:
## [br]- [method tile_movement] — animated, one tile, awaits 0.5 s, wont go into walls (grids that are not written in road TileMapLayer.
## [br]- [method snap_to_cell] — instant teleport to any cell, no animation, no wall check.
class_name mcBody
extends CharacterBody2D

## The tilemap that defines grid coordinates and walkable cells.
@onready var tiles: TileMapLayer = $"../RoadTileMapLayer"
var movement_delay := 0.28		## Time required to move each cell.
var _movement_generation := 0	
var _movement_tween: Tween
var _movement_start_position := Vector2.ZERO
var _movement_active := false

## Moves this body one cell in [param direction], if the destination is walkable.
##
## Waits 0.5 s, then checks the destination cell:
## [br]- If a tile exists there, snaps [member global_position] to that cell's centre.
## [br]- If not (source id [code]-1[/code]), the body does not move.
##
## This is a coroutine (uses [code]await[/code]). Callers must [code]await[/code]
## it if they need to sequence steps — otherwise the call returns immediately
## and the caller continues before the move has happened.
##
## [param direction] A cardinal direction as a [Vector2], e.g. [constant Vector2.UP],
## [constant Vector2.DOWN], [constant Vector2.LEFT], [constant Vector2.RIGHT].
## Converted to [Vector2i] internally.
func tile_movement(direction: Vector2) -> bool:
	# this function moves the character across the grid board, according to the "direction" parameter,
	# examples input for the direction: Vector2.UP, Vector2.Down, etc, other vector2 is unexpected input 

	assert(direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT], "unexpected input")

	# calculates current and destination cell/grid	
	var ticket := _movement_generation
	var target_cell := get_cell() + Vector2i(direction)
	
	
	# if target cell isnt placed as a ground level tile 
	if tiles.get_cell_source_id(target_cell)==-1: 
		## Adding bump animation.
		await bump(direction)
		return false

	# Convert grid coordinates to the target's world coordinates.
	var target_position := tiles.to_global(
		tiles.map_to_local(target_cell)
	)

	## Record the previous position.
	_movement_start_position = global_position
	_movement_active = true
	
	# Establish Tween.
	var tween := create_tween()
	_movement_tween = tween

	tween.tween_property(
		self, 
		"global_position", 
		target_position, 
		movement_delay
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Make sure that target won't be pulled back by the old animation after Reset/Stop.
	while tween.is_running():
		if ticket != _movement_generation:
			tween.kill()
			
			if _movement_tween == tween:
				_movement_tween = null
			return false

		await get_tree().process_frame
	
	if _movement_tween == tween:
		_movement_tween = null

	# If a Reset or Stop occurs before Tween completes, do not update the position.
	if ticket != _movement_generation:
		_movement_active = false
		return false

	# Ensure the final position falls in the center of the grid.
	global_position = target_position
	_movement_active = false
	return true


func get_cell() -> Vector2i:
	return tiles.local_to_map(tiles.to_local(global_position))

func can_move(direction: Vector2i) -> bool:
	return tiles.get_cell_source_id(get_cell() + direction) != -1

func cancel_pending_movement() -> void:
	_movement_generation += 1

	## To prevent the old Tween from continuing to change the target's position 
	## and pulling the target away from the starting point if the player presses Reset or Stop while moving.
	if _movement_tween != null and _movement_tween.is_valid():
		_movement_tween.kill()
		
	if _movement_active:
		global_position = _movement_start_position
		
	_movement_tween = null
	_movement_active = false

## Vibrates (left and right) or (back and forth) when hitting a wall.
func bump(direction: Vector2) -> void:
	var original_position := global_position
	var bump_offset := direction.normalized() * 10.0

	var tween := create_tween()
	_movement_tween = tween

	tween.tween_property(
		self,
		"global_position",
		original_position + bump_offset,
		0.06
	)

	tween.tween_property(
		self,
		"global_position",
		original_position,
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished

	if _movement_tween == tween:
		_movement_tween = null


## Instantly moves this body to the centre of [param cell].
##
## No animation, no delay, and no check that [param cell] has a tile under it —
## use this for resets and spawn placement, not for player-driven movement.
##
## [param cell] Target grid coordinate in [TileMapLayer] cell space.
func snap_to_cell(cell: Vector2i) -> void:
	cancel_pending_movement()
	# e.g. if cell is [0, 0], the chracter teleports to (0, 0) grid in the gridMapLayer
	global_position = tiles.to_global(tiles.map_to_local(cell))

## main character use this function to rescue target
## 
func rescue() -> void:
	## after rescuring target, play the "happy" animation on mcbody
	var mcbody_sprite: AnimatedSprite2D = $AnimatedSprite2D
	mcbody_sprite.play("happy")
