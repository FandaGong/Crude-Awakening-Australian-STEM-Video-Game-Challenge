@tool
extends EditorScript

const LEVEL_COUNT := 6
const LEVEL_TILEMAP_PATH := "res://levels/tilemaps/level_%02d_tiles.res"

func _run() -> void:
	var scene := get_scene() # the currently open/edited scene
	var levels_root := scene.get_node("World/Levels")
	for i in range(1, LEVEL_COUNT + 1):
		var level := levels_root.get_node_or_null("Level%d" % i)
		if not level:
			push_warning("Level%d not found" % i)
			continue
		var ground := level.get_node_or_null("Ground") as TileMapLayer
		if not ground:
			push_warning("Level%d/Ground not found" % i)
			continue
		var path := LEVEL_TILEMAP_PATH % i
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not res:
			push_warning("Could not load %s" % path)
			continue
		ground.tile_map_data = res.get("tile_map_data")
		print("Loaded tiles into Level%d/Ground" % i)
