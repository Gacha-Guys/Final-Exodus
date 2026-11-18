extends TextureProgressBar


var default_texture = preload("res://assets/inner.png")
var gamepass_texture = preload("res://assets/inner_gold.png")

@export var fill_texture: Texture2D:
	set(new_texture):
		fill_texture = new_texture
		texture_progress = new_texture

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fill_texture = gamepass_texture if PlayerData.gamepass else default_texture
	PlayerData.gamepass_success.connect(_on_gamepass_update)


func _on_gamepass_update() -> void:
	fill_texture = gamepass_texture if PlayerData.gamepass else default_texture
