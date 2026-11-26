extends Control

const RANK_PATH := "MarginContainer/NinePatchRect/MarginContainer/AspectRatioContainer/TextureProgressBar2/Label"
const FREE_LOGO := preload("res://assets/inner.png")
const PAID_LOGO := preload("res://assets/inner_gold.png")


var popup: CanvasLayer
var current_popup_key: String = "Home"


func _ready() -> void:
	
	var popup_dict := {
		"Shop": %ShopButton,
		"Home": %HomeButton,
		"Summon": %SummonButton,
		"Units": %UnitsButton,
	}
	
	for p in popup_dict:
		popup_dict[p].menu_button_pressed.connect(replace_popup.bind(p, popup_dict))
	
	#automatically go to the hub bg
	replace_popup(preload("res://scenes/hub/hub_popup.tscn"), "Home", popup_dict)
	
	PlayerData.currency_success.connect(_on_currency_changed)
	PlayerData.gamepass_success.connect(_on_gamepass_changed)
	_on_currency_changed()
	_on_gamepass_changed()
	if not GameSession.token.is_empty():
		await PlayerData.getCurrency(PlayerData.user_id)
	
func _on_currency_changed() -> void:
	%Currency.val = PlayerData.paid_currency
	#get_node(RANK_PATH).text = "Rank\n%d" % int(GameSession.account.level) if not GameSession.account.is_empty() else "Rank\n—"

func _on_gamepass_changed() -> void:
	%Logo.texture_progress = PAID_LOGO if PlayerData.has_gamepass else FREE_LOGO

func replace_popup(scene: PackedScene, popup_key: String, popup_dict: Dictionary) -> CanvasLayer:
	if is_instance_valid(popup):
		popup.queue_free()
		popup_dict[current_popup_key].unselect()
		
	if scene:
		popup = scene.instantiate()
		add_child(popup)
	
	popup_dict[popup_key].select()
	
	current_popup_key = popup_key
	
	return popup
