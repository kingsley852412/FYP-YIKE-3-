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
var movement_delay := 0.5
var _movement_generation := 0

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
	


	await get_tree().create_timer(movement_delay).timeout
	if ticket != _movement_generation:
		return false

	
	# if target cell isnt placed as a ground level tile 
	if tiles.get_cell_source_id(target_cell)!=-1:
		var traget_postion=tiles.to_global(tiles.map_to_local(target_cell))
		global_position=traget_postion
		return true
	return false

func get_cell() -> Vector2i:
	return tiles.local_to_map(tiles.to_local(global_position))

func can_move(direction: Vector2i) -> bool:
	return tiles.get_cell_source_id(get_cell() + direction) != -1

func cancel_pending_movement() -> void:
	_movement_generation += 1

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
