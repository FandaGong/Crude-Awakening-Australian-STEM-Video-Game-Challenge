extends Node2D

const ArenaScene := preload("res://arenas/boss_arena.tscn")
const TimeTravelOverlayScene := preload("res://ui/time_travel_overlay.tscn")
const BossScene := preload("res://bosses/boss.tscn")
const TimeMachineScene := preload("res://npc/time_machine.tscn")
const BlackHoleEffectScene := preload("res://effects/black_hole.tscn")
const GrayscaleOverlayScene := preload("res://effects/grayscale_overlay.tscn")
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
# exposes player_spawn / boss_spawn markers you can drag
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
const TIMELINE_SAMPLE_INTERVAL := 0.1
const TIMELINE_SECONDS := 3.0
var _timeline_timer: float = 0.0
var _timeline_history: Array[Dictionary] = []
var _grayscale_overlay: CanvasLayer
var _grayscale_material: ShaderMaterial

func _ready() -> void:
	add_to_group("world")
	_grayscale_overlay = GrayscaleOverlayScene.instantiate()
	add_child(_grayscale_overlay)
	_grayscale_material = _grayscale_overlay.get_node("BackBufferCopy/ColorRect").material as ShaderMaterial
	_set_grayscale_for_level(-1)
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	if levels_root:
		for i in range(1, LEVEL_COUNT + 1):
			level_nodes.append(levels_root.get_node_or_null("Level%d" % i))
	_set_level_atmosphere(-1)
	teleport_player_to_pond()

func _process(delta: float) -> void:
	if player and not player.isDead:
		_timeline_timer -= delta
		if _timeline_timer <= 0.0:
			_timeline_timer = TIMELINE_SAMPLE_INTERVAL
			_record_timeline_state()

func _record_timeline_state() -> void:
	var actors: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("corrupted_mobs") + get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(node):
			continue
		var actor: Dictionary = {"node": node, "position": node.global_position}
		if "velocity" in node:
			actor["velocity"] = node.velocity
		if "currentHealth" in node:
			actor["health"] = node.currentHealth
		if "current_health" in node:
			actor["health"] = node.current_health
		actors.append(actor)
	_timeline_history.append({"player": player.global_position, "actors": actors})
	while _timeline_history.size() > int(TIMELINE_SECONDS / TIMELINE_SAMPLE_INTERVAL):
		_timeline_history.pop_front()

func rewind_timeline(seconds: float = 1.5) -> void:
	if _timeline_history.is_empty():
		return
	var index := maxi(0, _timeline_history.size() - 1 - int(seconds / TIMELINE_SAMPLE_INTERVAL))
	var snapshot: Dictionary = _timeline_history[index]
	if player and player.has_method("rewind_to_recent_state"):
		player.rewind_to_recent_state(seconds)
	for actor_data in snapshot["actors"]:
		var actor = actor_data["node"]
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		actor.global_position = actor_data["position"]
		if actor_data.has("velocity") and "velocity" in actor:
			actor.velocity = actor_data["velocity"]
		if actor_data.has("health"):
			if "currentHealth" in actor:
				actor.currentHealth = actor_data["health"]
			elif "current_health" in actor:
				actor.current_health = actor_data["health"]
	_timeline_history.clear()

# --- Overworld areas --------------------------------------------------------

func teleport_player_to_pond() -> void:
	Effects.notify_level_changing()
	_set_level_atmosphere(-1)
	_clear_active_boss_arena()
	_clear_level_boss()
	_clear_level_time_machine()
	current_level_index = -1
	current_spawn_position = pond_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.LAND
	player.visible = true

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
	_set_level_atmosphere(-1)
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
	_set_level_atmosphere(-1)
	_clear_active_boss_arena()
	_clear_level_boss()
	_clear_level_time_machine()
	current_level_index = -1
	var spawn: Vector2 = lab_return_spawn.global_position if lab_return_spawn else pond_spawn.global_position
	current_spawn_position = spawn
	await _play_lab_arrival_effect(spawn)

## The robot's first instruction is spatial as well as verbal: it heads for
## the lab time machine and leaves a visible arrow trail for the otter.
func guide_player_to_time_machine() -> void:
	if not time_machine or GameData.has_seen_time_machine_guidance:
		return
	var robot := get_node_or_null("CompanionRobot")
	if robot and robot.has_method("guide_player_to"):
		GameData.has_seen_time_machine_guidance = true
		robot.guide_player_to(time_machine.global_position)

## After the first death, lead the otter from the return machine back to the
## scientist. Later deaths deliberately use only the rewind effect.
func guide_player_to_scientist() -> void:
	var scientist := pond_scene.get_node_or_null("Scientist") as Node2D if pond_scene else null
	var robot := get_node_or_null("CompanionRobot")
	if scientist and robot and robot.has_method("guide_player_to"):
		robot.guide_player_to(scientist.global_position)

func transitionToEnding() -> void:
	Effects.notify_level_changing()
	_set_level_atmosphere(-1)
	_clear_active_boss_arena()
	current_spawn_position = ending_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.LAND
	player.visible = true

func enter_dive_tunnel() -> void:
	Effects.notify_level_changing()
	_set_level_atmosphere(-1)
	_clear_active_boss_arena()
	current_spawn_position = dive_tunnel.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.SWIMMING
	player.visible = true

# --- Boss arenas -------------------------------------------------------------

func enter_boss_arena(boss_id: int) -> void:
	if not GameData.is_robot_unlocked:
		return
	var path := "res://resources/bosses/boss_%02d.tres" % boss_id
	if not ResourceLoader.exists(path):
		return

	Effects.notify_level_changing()
	AudioManager.play_music(AudioManager.Music.BOSS)
	current_boss_data = load(path)
	_clear_active_boss_arena()

	current_boss_arena = ArenaScene.instantiate()
	add_child(current_boss_arena)
	current_boss_arena.global_position = ARENA_OFFSET
	current_boss_arena.setup(current_boss_data)
	current_boss_arena.boss_defeated.connect(_on_arena_boss_defeated)

	player.global_position = current_boss_arena.global_position + current_boss_arena.player_spawn.position
	player.currentState = player.State.SWIMMING
	player.visible = true
	current_spawn_position = player.global_position

func _on_arena_boss_defeated(boss_id: int) -> void:
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
	_set_level_atmosphere(era_index)
	_set_grayscale_for_level(era_index)

	current_spawn_position = level.player_spawn.global_position
	player.global_position = current_spawn_position
	player.currentState = player.State.SWIMMING
	player.visible = true

	_spawn_level_time_machine(level, era_index)

	var clear_callback := _on_level_mobs_cleared.bind(era_index)
	if level.has_signal("mobs_cleared") and not level.is_connected("mobs_cleared", clear_callback):
		level.connect("mobs_cleared", clear_callback)
	level.set_mobs_active(false)
	_show_level_briefing(era_index)

## Only the atmosphere belonging to the active historical level is allowed to
## render. The level scenes remain loaded for their mobs and terrain, but
## their parallax background layers cannot bleed into another level or the
## laboratory hub.
func _set_level_atmosphere(active_index: int) -> void:
	AudioManager.play_music(AudioManager.Music.WATER if active_index >= 0 else AudioManager.Music.LAND)
	for i in range(level_nodes.size()):
		var level: Node = level_nodes[i]
		if not level:
			continue
		var atmosphere := level.get_node_or_null("atmosphere") as CanvasItem
		if atmosphere:
			atmosphere.visible = i == active_index

func _set_grayscale_for_level(era_index: int) -> void:
	if not _grayscale_material:
		return
	var grayscale_amount := 0.0
	if era_index >= 0 and LEVEL_COUNT > 1:
		grayscale_amount = 1.0 - float(era_index) / float(LEVEL_COUNT - 1)
	_grayscale_material.set_shader_parameter("grayscale_amount", grayscale_amount)

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
		_start_first_level_guidance(level, era_index)
		# Re-entering a level whose field mobs were already cured before the
		# otter died to its boss: mobs_cleared already fired once and won't
		# fire again, so spawn the boss directly instead of waiting forever.
		if level.has_method("mobs_already_cleared") and level.mobs_already_cleared():
			_spawn_level_boss(level, era_index)
	dialogue_box.finished.connect(on_briefing_done, CONNECT_ONE_SHOT)

## The robot teaches the full encounter loop once, in the first era.  It
## leads to the field-mob area after the briefing, then world progression
## advances that same arrow trail to the boss and finally to the return
## machine.  The flag is set when this sequence begins so a death/re-entry
## cannot restart the tutorial partway through.
func _start_first_level_guidance(level: Node, era_index: int) -> void:
	if era_index != 0 or GameData.has_seen_first_level_guidance:
		return
	if not level or not level.mob_spawn_center:
		return
	GameData.has_seen_first_level_guidance = true
	_guide_player_to(level.mob_spawn_center.global_position)

func _guide_player_to(destination: Vector2) -> void:
	var robot := get_node_or_null("CompanionRobot")
	if robot and robot.has_method("guide_player_to"):
		robot.guide_player_to(destination)

func _on_level_mobs_cleared(era_index: int) -> void:
	if era_index != current_level_index:
		return
	var level: Node = level_nodes[era_index]
	if level:
		_spawn_level_boss(level, era_index)
		if era_index == 0 and GameData.has_seen_first_level_guidance and level.boss_spawn:
			_guide_player_to(level.boss_spawn.global_position)

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
	AudioManager.play_music(AudioManager.Music.BOSS)
	current_level_boss = BossScene.instantiate()
	current_level_boss.boss_data = current_level_boss_data
	level.add_child(current_level_boss)
	current_level_boss.global_position = level.boss_spawn.global_position
	current_level_boss.defeated.connect(_on_level_boss_defeated.bind(era_index))

func _on_level_boss_defeated(_boss_id: int, _era_index: int) -> void:
	AudioManager.play_music(AudioManager.Music.WATER)
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
		if _era_index == 0 and GameData.has_seen_first_level_guidance:
			_guide_player_to(current_level_time_machine.global_position)

func _clear_level_boss() -> void:
	if current_level_boss and is_instance_valid(current_level_boss):
		current_level_boss.queue_free()
	current_level_boss = null
	current_level_boss_data = null

# --- Shop --------------------------------------------------------------------



# --- Death / respawn -----------------------------------------------------------

func _on_player_died() -> void:
	player.set_physics_process(false)
	player.visible = false
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	var show_death_guidance := not GameData.has_seen_death_guidance
	if dialogue_box and show_death_guidance:
		GameData.has_seen_death_guidance = true
		dialogue_box.show_lines(PackedStringArray(["Robot: Temporal recovery initiated. Follow me to the scientist for recalibration."]))
		await dialogue_box.finished
	_play_rewind_screen()
	await get_tree().create_timer(1.1).timeout
	var level_to_reset := current_level_index
	if level_to_reset >= 0 and level_to_reset < level_nodes.size():
		var level: Node = level_nodes[level_to_reset]
		if level and level.has_method("reset_encounter"):
			level.reset_encounter()
	_clear_level_boss()
	_timeline_history.clear()
	await return_to_time_machine()
	player.respawn(current_spawn_position)
	player.set_physics_process(true)
	if show_death_guidance:
		guide_player_to_scientist()

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
