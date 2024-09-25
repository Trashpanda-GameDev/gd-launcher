extends Label

func _ready():
	var project_version = ProjectSettings.get_setting("application/config/version")
	self.text = project_version
