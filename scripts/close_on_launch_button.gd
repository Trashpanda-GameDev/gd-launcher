extends CheckButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var saved_toggle_state = Globals.config.get_value("settings", "close_on_launch", false)
	if saved_toggle_state != null:
		print("Saved toggle state: ", saved_toggle_state)
		self.button_pressed = saved_toggle_state
	toggled.connect(_onToggled)

func _onToggled(event):
	Globals.closeOnLaunch = event
	Globals.config.set_value("settings","close_on_launch", event)
	Globals.config.save("user://settings.cfg")
