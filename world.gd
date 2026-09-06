extends Node2D

const ArenaScene := preload("res://arenas/boss_arena.tscn")
const TimeTravelOverlayScene := preload("res://ui/time_travel_overlay.tscn")
const BossScene := preload("res://bosses/boss.tscn")
const TimeMachineScene := preload("res://npc/time_machine.tscn")
const BlackHoleEffectScene := preload("res://effects/black_hole.tscn")
const ARENA_OFFSET := Vector2(6000, 0)
const LEVEL_COUNT := 6

@onready var pond_scene: Node2D = $pondScene
@onready var ending_scene: Node2D = $endingScene
@onready var dive_tunnel: Node2D = $diveTunnel
@onready var levels_root: Node2D = $Levels

@onready var pond_spawn: Marker2D = $pondScene/pondSpawn
@onready var lab_return_spawn: Marker2D = $pondScene/labReturnSpawn
@onready var ending_spawn: Marker2D = $endingScene/endingSpawn

@onready var player: CharacterBody2D = $player
@onready var time_machine: Area2D = $pondScene/TimeMachine

var current_spawn_position: Vector2 = Vector2.ZERO
var current_boss_arena: Node = null
var current_boss_data: BossData = null

# --- New hand-drawn level system --------------------------------------------
# level_nodes[0] is Level1 (era index 0 / boss_01), level_nodes[5] is Level6
# (era index 5 / boss_06). Each level node comes from levels/level.gd and
# exposes player_spawn / boss_spawn / trader_spawn markers you can drag
# around in the editor.
var level_nodes: Array = []
var current_level_index: int = -1 # -1 = not currently inside a level
var current_level_boss: Node = null
var current_level_boss_data: BossData = null

# The return-trip time machine dropped into the current level (see
# _spawn_level_time_machine()). It always sits at that level's player_spawn
# marker - the same coordinates the otter arrives at - and stays inert
# until its level's boss is cured.
var current_level_time_machine: Area2D = null

func _ready() -> void:
	add_to_group("world")
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	if levels_root:
		for i in range(1, LEVEL_COUNT + 1):
			level_nodes.append(levels_root.get_node_or_null("Level%d" % i))
	teleport_player_to_pond()

# --- Overworld areas --------------------------------------------------------

func teleport_player_to_pond() -> void:
	Effects.notify_level_changing()
	_clear_active_boss_arena()
	_clear_level_boss()
	_clear_level_time_machine()
	current_level_index = -1
	current_spawn_position = pond_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.LAND

## Sends the player back to the scientist's lab hub (the 2126 wasteland
## around pondScene) without re-running the opening pond sequence. Called
## once the otter actually uses a level's own time machine after its boss
## has been cured (see _on_level_boss_defeated() / time_machine.gd), so the
## otter can catch its breath and walk back into the main time machine for
## the next Historical Turning Point.
##
## Rather than just popping into existence at labReturnSpawn, the otter now
## visibly steps back out of the original lab time machine itself: a small
## black hole opens up on it, the otter hops out, and the hole shrinks away.
func return_to_lab() -> void:
	Effects.notify_level_changing()
	_clear_active_boss_arena()
	_clear_level_boss()
	_clear_level_time_machine()
	current_level_index = -1
	var fallback: Marker2D = lab_return_spawn if lab_return_spawn else pond_spawn
	var spawn_pos: Vector2 = (
		time_machine.global_position + Vector2(18.0, 55.0)
		if time_machine else fallback.global_position
	)
	current_spawn_position = spawn_pos
	_play_lab_arrival_effect(spawn_pos)

## Grows a small black hole at spawn_pos, pops the otter out of it once
## it's fully open, then shrinks the hole away and frees it.
func _play_lab_arrival_effect(spawn_pos: Vector2) -> void:
	player.currentState = player.State.LAND
	var original_scale: Vector2 = player.scale
	player.visible = false

	var hole := BlackHoleEffectScene.instantiate()
	add_child(hole)
	hole.global_position = spawn_pos
	await hole.grow()

	player.global_position = spawn_pos
	player.scale = original_scale
	player.visible = true

	# A little hop "out of" the hole rather than just appearing flat-footed.
	var hop := create_tween()
	hop.tween_property(player, "global_position:y", spawn_pos.y - 20.0, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(player, "global_position:y", spawn_pos.y, 0.2) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await hop.finished

	await hole.shrink_and_free()

## Sends the player right to the time machine's doorway instead of the
## general lab spawn. Used only when the otter dies mid-level and gets
## rewound back through the machine, so they visibly step back out of it
## rather than just reappearing somewhere in the lab.
func return_to_time_machine() -> void:
	Effects.notify_level_changing()
	_clear_active_boss_arena()
	_clear_level_boss()
	_clear_level_time_machine()
	current_level_index = -1
	var spawn: Vector2 = lab_return_spawn.global_position if lab_return_spawn else pond_spawn.global_position
	if time_machine:
		spawn = time_machine.global_position + Vector2(18.0, 55.0)
	current_spawn_position = spawn
	player.global_position = current_spawn_position
	player.currentState = player.State.LAND

func transitionToEnding() -> void:
	Effects.notify_level_changing()
	_clear_active_boss_arena()
	current_spawn_position = ending_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.LAND

func enter_dive_tunnel() -> void:
	Effects.notify_level_changing()
	_clear_active_boss_arena()
	current_spawn_position = dive_tunnel.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.SWIMMING

# --- Boss arenas -------------------------------------------------------------

func enter_boss_arena(boss_id: int) -> void:
	if not GameData.is_robot_unlocked:
		return
	var path := "res://resources/bosses/boss_%02d.tres" % boss_id
	if not ResourceLoader.exists(path):
		return

	Effects.notify_level_changing()
	current_boss_data = load(path)
	_clear_active_boss_arena()

	current_boss_arena = ArenaScene.instantiate()
	add_child(current_boss_arena)
	current_boss_arena.global_position = ARENA_OFFSET
	current_boss_arena.setup(current_boss_data)
	current_boss_arena.boss_defeated.connect(_on_arena_boss_defeated)

	player.global_position = current_boss_arena.global_position + current_boss_arena.player_spawn.position
	player.currentState = player.State.SWIMMING
	current_spawn_position = player.global_position

func _on_arena_boss_defeated(boss_id: int, _crystal_reward: int) -> void:
	await get_tree().create_timer(1.5).timeout
	_clear_active_boss_arena()

	# Curing a boss sends the robot & otter forward to the next Historical
	# Turning Point (or, once the Kraken/AI itself is cured, all the way
	# home to 2126 to see the restored timeline).
	StoryManager.advance_to_next_era()
	var overlay := TimeTravelOverlayScene.instantiate()
	add_child(overlay)
	if StoryManager.current_era_index >= StoryManager.ERAS.size():
		overlay.play(StoryManager.HOME_YEAR, "The timeline is finally clear.")
		await overlay.finished
		transitionToEnding()
	else:
		var era: Dictionary = StoryManager.ERAS[StoryManager.current_era_index]
		overlay.play(era.year, era.title)
		await overlay.finished
		_return_to_tunnel_from_boss(boss_id)

func _return_to_tunnel_from_boss(boss_id: int) -> void:
	_clear_active_boss_arena()
	if not dive_tunnel:
		return
	var gate_pos: Vector2 = dive_tunnel.boss_gate_positions.get(boss_id, Vector2.ZERO)
	player.global_position = dive_tunnel.global_position + gate_pos + Vector2(0, 90)
	player.currentState = player.State.SWIMMING
	current_spawn_position = player.global_position

func _clear_active_boss_arena() -> void:
	if current_boss_arena and is_instance_valid(current_boss_arena):
		current_boss_arena.queue_free()
	current_boss_arena = null

# --- Hand-drawn levels ---------------------------------------------------------
# Called by the time machine (see npc/time_machine.gd) each time it sends the
# otter to a new Historical Turning Point. era_index is 0-based and matches
# StoryManager.current_era_index (0 -> Level1/boss_01, ... 5 -> Level6/boss_06).

func enter_level(era_index: int) -> void:
	if era_index < 0 or era_index >= level_nodes.size():
		return
	var level: Node = level_nodes[era_index]
	if not level:
		push_warning("world.gd: Levels/Level%d is missing from the scene." % (era_index + 1))
		return

	Effects.notify_level_changing()
	_clear_active_boss_arena()
	_clear_level_boss()
	current_level_index = era_index

	current_spawn_position = level.player_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.SWIMMING

	_spawn_level_time_machine(level, era_index)

	var clear_callback := _on_level_mobs_cleared.bind(era_index)
	if level.has_signal("mobs_cleared") and not level.is_connected("mobs_cleared", clear_callback):
		level.connect("mobs_cleared", clear_callback)
	level.set_mobs_active(false)
	_show_level_briefing(era_index)

## Drops this level's return-trip time machine right on top of the otter's
## spawn point - the same coordinates every time this level is entered -
## and plays its grow-in effect since it's appearing alongside them. It
## stays inert (see time_machine.gd) until this level's boss is cured.
func _spawn_level_time_machine(level: Node, era_index: int) -> void:
	_clear_level_time_machine()
	current_level_time_machine = TimeMachineScene.instantiate()
	level.add_child(current_level_time_machine)
	current_level_time_machine.global_position = level.player_spawn.global_position
	current_level_time_machine.is_return_machine = true
	if GameData.is_boss_defeated(era_index + 1):
		# Re-entering an already-cured level (shouldn't normally happen,
		# but just in case) - let it work immediately.
		current_level_time_machine.enable_return()
	if current_level_time_machine.has_method("play_spawn_effect"):
		current_level_time_machine.play_spawn_effect()

func _clear_level_time_machine() -> void:
	if current_level_time_machine and is_instance_valid(current_level_time_machine):
		current_level_time_machine.queue_free()
	current_level_time_machine = null

func _show_level_briefing(era_index: int) -> void:
	if era_index < 0 or era_index >= StoryManager.ERAS.size():
		return
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if not dialogue_box:
		return
	var era: Dictionary = StoryManager.ERAS[era_index]
	var briefing: Array = era.get("briefing", [])
	dialogue_box.show_lines(PackedStringArray(briefing))
	var level: Node = level_nodes[era_index]
	var on_briefing_done := func() -> void:
		level.set_mobs_active(true)
		# Re-entering a level whose field mobs were already cured before the
		# otter died to its boss: mobs_cleared already fired once and won't
		# fire again, so spawn the boss directly instead of waiting forever.
		if level.has_method("mobs_already_cleared") and level.mobs_already_cleared():
			_spawn_level_boss(level, era_index)
	dialogue_box.finished.connect(on_briefing_done, CONNECT_ONE_SHOT)

func _on_level_mobs_cleared(era_index: int) -> void:
	if era_index != current_level_index:
		return
	var level: Node = level_nodes[era_index]
	if level:
		_spawn_level_boss(level, era_index)

func _spawn_level_boss(level: Node, era_index: int) -> void:
	if current_level_boss and is_instance_valid(current_level_boss):
		return # each level can have only its own single active boss instance
	var boss_id := era_index + 1
	if GameData.is_boss_defeated(boss_id):
		return # already cured - leave the level boss-free from now on
	var path := "res://resources/bosses/boss_%02d.tres" % boss_id
	if not ResourceLoader.exists(path):
		return

	current_level_boss_data = load(path)
	current_level_boss = BossScene.instantiate()
	current_level_boss.boss_data = current_level_boss_data
	level.add_child(current_level_boss)
	current_level_boss.global_position = level.boss_spawn.global_position
	current_level_boss.defeated.connect(_on_level_boss_defeated.bind(era_index))

func _on_level_boss_defeated(_boss_id: int, _crystal_reward: int, _era_index: int) -> void:
	await get_tree().create_timer(1.5).timeout
	_clear_level_boss()
	# The otter no longer teleports home automatically - the level's own
	# time machine (dropped at their spawn point when the level began) is
	# now switched on. Stepping into it is what actually rides them back
	# to labReturnSpawn (see time_machine.gd/_activate()); interacting with
	# the lab's own machine there is what then advances StoryManager to the
	# next era, or - after the sixth boss - out into the restored ending.
	if current_level_time_machine and is_instance_valid(current_level_time_machine):
		current_level_time_machine.enable_return()

func _clear_level_boss() -> void:
	if current_level_boss and is_instance_valid(current_level_boss):
		current_level_boss.queue_free()
	current_level_boss = null
	current_level_boss_data = null

# --- Shop --------------------------------------------------------------------

func open_shop() -> void:
	get_tree().call_group("ui_controller", "open_shop")

# --- Death / respawn -----------------------------------------------------------

func _on_player_died() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box:
		dialogue_box.show_lines(PackedStringArray(["Robot: Well, that was unfortunate. We can only go back in time and try again."]))
		await dialogue_box.finished
	_play_rewind_screen()
	await get_tree().create_timer(1.1).timeout
	GameData.time_revival_pending = true
	return_to_time_machine()
	player.respawn(current_spawn_position)

func _play_rewind_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.08, 0.22, 0.2, 0.0)
	layer.add_child(overlay)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -170.0
	label.offset_top = -18.0
	label.offset_right = 170.0
	label.offset_bottom = 18.0
	label.text = "REWINDING THE TIMELINE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("b9fff4"))
	layer.add_child(label)
	get_tree().current_scene.add_child(layer)
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.88, 0.25)
	tween.tween_property(overlay, "color:a", 0.0, 0.8)
	tween.tween_callback(layer.queue_free)
