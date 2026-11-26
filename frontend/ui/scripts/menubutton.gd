@tool
class_name NavMenuButton
extends Control

const scene_dict := {
	"Shop": preload("res://scenes/shop/shop.tscn"),
	"Home": preload("res://scenes/hub/hub_popup.tscn"),
	"": null,
}

signal menu_button_pressed(popup)

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
			

		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = text
	$TextureRect.texture = icon_texture
	
	if Engine.is_editor_hint(): # if in the editor  then don't do what we're about to do
		return
	

func _gui_input(event: InputEvent) -> void:
		
	if event is InputEventMouseButton:
		if event.is_pressed():
			select()
		if event.is_released():
			unselect()
			if scene_dict[text]:
				menu_button_pressed.emit(scene_dict[text])
				
				
				
func select():
	$NinePatchRect.modulate = Color(1.3, 1.3, 1.3, 1.0)
	
func unselect():
	$NinePatchRect.modulate = Color(1.0, 1.0, 1.0, 1.0)
