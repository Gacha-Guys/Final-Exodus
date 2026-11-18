extends Control

const FIGHTERS := preload("res://assets/battle/fighters.png")
const LANDSCAPE := preload("res://assets/banishment.png")
const POSITIONS: Array[Vector2] = [Vector2(0.25, 0.53), Vector2(0.14, 0.72), Vector2(0.34, 0.87), Vector2(0.77, 0.68)]
const ENEMY := 3
signal hit_shown(hit: Dictionary)
signal counter_shown(counter: Dictionary)

var sprites: Array[TextureRect] = []

func portrait(index: int) -> AtlasTexture:
	var tile := FIGHTERS.get_size() / 2.0
	var texture := AtlasTexture.new()
	texture.atlas = FIGHTERS
	texture.region = Rect2(Vector2(index % 2, floori(index / 2.0)) * tile, tile)
	texture.filter_clip = true
	return texture

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scenery := TextureRect.new()
	scenery.texture = LANDSCAPE
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.modulate = Color(0.60, 0.65, 0.77)
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scenery)
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in range(4):
		var sprite := TextureRect.new()
		sprite.texture = portrait(index)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
		sprites.append(sprite)
	resized.connect(arrange)
	arrange()

func rest_position(index: int) -> Vector2:
	return size * POSITIONS[index] - sprites[index].size * Vector2(0.5, 0.9)

func arrange() -> void:
	for index in range(sprites.size()):
		var width := minf(size.x * 0.30, size.y * 0.46)
		if index == ENEMY:
			width *= 1.55
		sprites[index].size = Vector2.ONE * width
		sprites[index].position = rest_position(index)

func cue(index: int) -> void:
	var sprite := sprites[index]
	create_tween().tween_property(sprite, "position", rest_position(index) + Vector2(22, -14), 0.12)

func popup(index: int, message: String, color: Color, lane: int) -> void:
	var number := Label.new()
	number.text = message
	number.add_theme_font_size_override("font_size", 32)
	number.add_theme_constant_override("outline_size", 7)
	number.modulate = color
	number.position = size * POSITIONS[index] - Vector2(56, sprites[index].size.y * 0.7 + 32 * lane)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(number)
	var tween := create_tween().set_parallel()
	tween.tween_property(number, "position:y", number.position.y - 34, 0.48)
	tween.tween_property(number, "modulate:a", 0.0, 0.24).set_delay(0.30)
	tween.chain().tween_callback(number.queue_free)

func lunge(index: int, target: int, duration: float) -> void:
	var sprite := sprites[index]
	var home := rest_position(index)
	var contact := home + (size * (POSITIONS[target] - POSITIONS[index])) * 0.77
	var tween := create_tween()
	tween.tween_property(sprite, "position", contact, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", home, 0.18)

func flash(index: int) -> void:
	var sprite := sprites[index]
	sprite.modulate = Color(2.2, 1.15, 0.8)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)

func impact(hit: Dictionary, lane: int) -> void:
	flash(ENEMY)
	var amount := str(int(hit.damage))
	popup(ENEMY, "Combo! " + amount if hit.combo else amount, Color("#ffdf96"), lane)
	hit_shown.emit(hit)

func retaliate(counter: Dictionary) -> void:
	var index := int(counter.actor)
	flash(index)
	popup(index, str(int(counter.damage)), Color("#ffbbae"), 0)
	counter_shown.emit(counter)

func valid_hit(hit: Variant) -> bool:
	return hit is Dictionary and GameSession.number(hit.get("actor")) and hit.actor == int(hit.actor) \
		and hit.actor < ENEMY and GameSession.number(hit.get("hp")) and GameSession.number(hit.get("damage"))

func can_replay(result: Variant) -> bool:
	if not result is Dictionary or not result.get("hits") is Array or result.hits.size() not in [1, 2, 3]:
		return false
	for hit in result.hits:
		if not valid_hit(hit) or not GameSession.number(hit.get("at_ms")) or hit.at_ms > 1450 or not hit.get("combo") is bool:
			return false
	return result.has("counter") and (result.counter == null or valid_hit(result.counter))

func play_round(result: Dictionary) -> void:
	var timeline := create_tween().set_parallel()
	var last_hit := 0.0
	for lane in range(result.hits.size()):
		var hit: Dictionary = result.hits[lane]
		last_hit = float(hit.at_ms) / 1000.0
		var dash := minf(0.19, last_hit)
		timeline.tween_callback(lunge.bind(int(hit.actor), ENEMY, dash)).set_delay(last_hit - dash)
		timeline.tween_callback(impact.bind(hit, lane)).set_delay(last_hit)
	var finish := last_hit + 0.25
	if result.counter is Dictionary:
		timeline.tween_callback(lunge.bind(ENEMY, int(result.counter.actor), 0.20)).set_delay(finish)
		finish += 0.20
		timeline.tween_callback(retaliate.bind(result.counter)).set_delay(finish)
	timeline.tween_interval(finish + 0.26)
	await timeline.finished
	arrange()

func sync_units(state: Dictionary) -> void:
	for index in range(ENEMY):
		sprites[index].modulate = Color.WHITE if state.party[index].hp > 0 else Color("#686b78")
	sprites[ENEMY].modulate = Color.WHITE if state.enemy.hp > 0 else Color("#767488")
