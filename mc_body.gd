extends CharacterBody2D

@onready var tiles: TileMapLayer = $"../RoadTileMapLayer"

func tile_movement(direction:Vector2):
	var current_cell=tiles.local_to_map(tiles.to_local(global_position))
	var target_cell=current_cell+Vector2i(direction)
	
	if tiles.get_cell_source_id(target_cell)!=-1:
		var traget_postion=tiles.to_global(tiles.map_to_local(target_cell))
		global_position=traget_postion
