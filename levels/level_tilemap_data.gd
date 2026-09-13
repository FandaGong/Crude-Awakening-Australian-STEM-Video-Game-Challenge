class_name LevelTileMapData
extends Resource

## Binary payload for one level's Ground TileMapLayer.  Resources are loaded
## on demand by World, so inactive levels keep no tile cells in memory.
@export var tile_map_data: PackedByteArray
