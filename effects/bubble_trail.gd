extends Node2D

## Small cosmetic bubble spawned behind the otter while it swims. Drifts
## upward with a little wobble and fades out, then frees itself. Purely
## visual - see Effects.spawn_bubble_trail(), called from player.gd's
## handleSwimmingMovement().

const BUBBLE_SHEET_PATH := "res://assets/sprites/mobs/bubble.png"

@onready var sprite: Sprite2D = $Sprite2D

func setup() -> void:
	if sprite and ResourceLoader.exists(BUBBLE_SHEET_PATH):
		var sheet := load(BUBBLE_SHEET_PATH) as Texture2D
		if sheet and sheet.get_height() > 0:
			var frame_size := sheet.get_height()
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(0, 0, frame_size, frame_size)
			sprite.texture = atlas

	z_index = 5
	position += Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))

	var start_scale := randf_range(0.10, 0.22)
	scale = Vector2(start_scale, start_scale)
	modulate.a = randf_range(0.35, 0.55)

	var rise := randf_range(26.0, 46.0)
	var wobble := randf_range(-12.0, 12.0)
	var start_pos := position
	var lifetime := randf_range(0.7, 1.1)

	var drift := create_tween()
	drift.set_parallel(true)
	drift.tween_property(self, "position", start_pos + Vector2(wobble, -rise), lifetime) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.tween_property(self, "scale", scale * 1.5, lifetime) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var fade := create_tween()
	fade.tween_interval(lifetime * 0.55)
	fade.tween_property(self, "modulate:a", 0.0, lifetime * 0.45)
	fade.tween_callback(queue_free)
