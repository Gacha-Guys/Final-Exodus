@tool
extends Control

var is_paid_shop

var paid_pressed = preload("res://assets/blue_pressed.png")
var paid_normal = preload("res://assets/blue.png")

var free_pressed = preload("res://assets/grey_pressed.png")
var free_normal = preload("res://assets/grey.png")

var gamepass = preload("res://assets/inner_gold.png")
var gem = preload("res://assets/gem.png")

var count = 0
var type := ""

var item_id = null

var item_cost = 0
var premium = false



@export var button_texture: Texture2D:
	set(value):
		button_texture = value
		if is_node_ready():
			%ShopButton.texture = value

@export_multiline var pricetag_text: String:
	set(value):
		pricetag_text = value
		if is_node_ready():
			%Pricetag.text = value

@export var font_size: int:
	set(value):
		font_size = value
		if is_node_ready():
			%Pricetag.add_theme_font_size_override("font_size", value)

@export var pricetag_margin: float:
	set(value):
		pricetag_margin = value
		if is_node_ready():
			%PricetagMargin.add_theme_constant_override("margin_right", value)

@export var item_texture: Texture2D:
	set(value):
		item_texture = value
		if is_node_ready():
			if item_texture == gamepass:
				%LogoMargin.visible = true
				%GemMargin.visible = false
				%ItemMargin.visible = false
				type = "Logo"
			elif item_texture == gem:
				%LogoMargin.visible = false
				%GemMargin.visible = true
				%ItemMargin.visible = false
				_gem()
				type = "Gem"
			else:
				%LogoMargin.visible = false
				%GemMargin.visible = false
				%ItemMargin.visible = true
				%ItemTexture.texture = value
				type = "Item"

@export var bottom_item_margin: float:
	set(value):
		bottom_item_margin = value
		if is_node_ready():
			_margin("margin_bottom", value)
			

@export var left_item_margin: float:
	set(value):
		left_item_margin = value
		if is_node_ready():
			_margin("margin_left", value)

@export var top_item_margin: float:
	set(value):
		top_item_margin = value
		if is_node_ready():
			_margin("margin_top", value)

@export var set_count: int = 0:
	set(value):
		set_count = value
		count = value
		if type == "Gem":
			_gem()

@export var set_item_id: int:
	set(value):
		set_item_id = value
		item_id = value

@export var set_paid_shop: bool:
	set(value):
		set_paid_shop = value;
		is_paid_shop = value
		if is_node_ready():
			if (value):
				button_texture = paid_normal
				%Pricetag.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			else:
				button_texture = free_normal
				%Pricetag.add_theme_color_override("font_color", Color())

@export var set_cost: int:
	set(value):
		set_cost = value
		item_cost = value

@export var is_premium: bool:
	set(value):
		is_premium = value
		premium = value
		
@export var texture_size: Vector2 = Vector2(64, 64):
	set(value):
		texture_size = value
		if is_node_ready():
			_apply_texture_size()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button_texture = button_texture
	_update_pricetag_color()
	pricetag_text = pricetag_text
	font_size = font_size
	pricetag_margin = pricetag_margin
	item_texture = item_texture          
	bottom_item_margin = bottom_item_margin
	left_item_margin = left_item_margin
	top_item_margin = top_item_margin
	set_count = set_count
	set_cost = set_cost
	is_premium = is_premium
	_apply_texture_size()
	


func _update_pricetag_color() -> void:
	if is_node_ready():
		%Pricetag.add_theme_color_override("font_color", Color.WHITE if is_paid_shop else Color.BLACK)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			button_texture = paid_pressed if is_paid_shop else free_pressed
			
		if event.is_released():
			button_texture = paid_normal if is_paid_shop else free_normal
			


func _margin(side: String, val):
	match (type):
		"Logo":
			%LogoMargin.add_theme_constant_override(side, val)
		"Gem":
			%GemMargin.add_theme_constant_override(side, val)
		"Item":
			%ItemMargin.add_theme_constant_override(side, val)

func _gem():
	%Gem1.visible = count == 1
	%Gem2.visible = count == 2
	%Gem3.visible = count == 3
	%Gem4.visible = count == 4


func _apply_texture_size() -> void:
	%ItemTexture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	%ItemTexture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	%ItemTexture.custom_minimum_size = texture_size
