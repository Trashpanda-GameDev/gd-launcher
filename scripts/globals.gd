extends Node

var config = ConfigFile.new()
var closeOnLaunch = false;

func _ready() -> void:
	setup_config();
	closeOnLaunch = config.get_value("settings","close_on_launch", false)

func setup_config():
	var err = config.load("user://settings.cfg")
	if err != OK:
		config.save("user://settings.cfg")
