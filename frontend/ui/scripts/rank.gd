extends Label

var str = "Rank\n"

@export var level_text: String:
	set(new_text):
		level_text = new_text
		text = new_text

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if Engine.is_editor_hint():
		return
	
	level_text = str + str(PlayerData.level)
	PlayerData.level_success.connect(_on_level_change)
	
func _on_level_change() -> void:
	level_text = str + str(PlayerData.level)
