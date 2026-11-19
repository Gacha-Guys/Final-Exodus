@tool
class_name NavMenuButton
extends Control

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			$TextureRect.texture = icon_texture
			
@export var text: String = "Button":
	set(value):
		text = value
		if is_node_ready():
			$Label.text = text
			
@export_file("*.tscn") var target_scene: String

var _is_current_page := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = text
	$TextureRect.texture = icon_texture
	
	if Engine.is_editor_hint(): # if in the editor  then don't do what we're about to do
		return
	
	# get the current page and see if target_scene is non-existent or if the current page doesn't exist or if the current page does equal the target page
	var current := get_tree().current_scene
	_is_current_page = target_scene == "" or (current and current.scene_file_path == target_scene)
	
	if _is_current_page: # if any of that is true, make it look selected
		$NinePatchRect.modulate = Color(1.3, 1.3, 1.3, 1.0)
	



	
func _gui_input(event: InputEvent) -> void:
	if _is_current_page: # don't handle any input if we are on the page it points or there is no destination
		return
		
	if event is InputEventMouseButton and target_scene:
		if event.is_pressed():
			$NinePatchRect.modulate = Color(1.3, 1.3, 1.3, 1.0)
		if event.is_released():
			$NinePatchRect.modulate = Color(1.0, 1.0, 1.0, 1.0)
			get_tree().change_scene_to_file(target_scene)
