extends CharacterBody2D

@onready var tiles: TileMapLayer = $"../RoadTileMapLayer"

func tile_movement(direction:Vector2):
	# this function moves the character across the grid board, according to the "direction" parameter,
	# examples input for the direction: Vector2.UP, Vector2.Down, etc.

	# calculates current and destination cell/grid	
	var current_cell=tiles.local_to_map(tiles.to_local(global_position))
	var target_cell=current_cell+Vector2i(direction)

	await get_tree().create_timer(0.5).timeout

	
	# if target cell isnt placed as a ground level tile 
	if tiles.get_cell_source_id(target_cell)!=-1:
		var traget_postion=tiles.to_global(tiles.map_to_local(target_cell))
		global_position=traget_postion
