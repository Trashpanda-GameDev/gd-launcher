extends CheckButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	toggled.connect(_onToggled)

func _onToggled(event):
	Globals.closeOnLaunch = event
