extends Control

var itemButton = preload("res://ui/itembutton.tscn")
var texture = preload("res://assets/gem.png") # Remove this with actual implementation

@onready
var grid = $ScrollContainer/GridContainer

func refresh():
	for child in grid.get_children():
		child.queue_free()

func addItem(name: String, count: int, texture: Texture2D):
	var item = itemButton.instantiate()
	item.item_name = name
	item.item_count = count
	item.texture = texture
	grid.add_child(item)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# Remove this loop with actual implementation
	for i in range(100):
		addItem("Test", i, texture)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
