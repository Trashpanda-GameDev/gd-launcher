extends HBoxContainer

@onready var name_label: Label = $NameLabel
@onready var path_label: Label = $PathLabel
@onready var version_label: Label = $VersionLabel
@onready var launch_button: Button = $LaunchButton

@export var nameText = ""
@export var pathText = ""
@export var versionText = ""
@export var executablePath = ""
@export var buttonDisabled = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	path_label.text = pathText
	version_label.text = versionText
	name_label.text = nameText
	var buttonState = "enabled"
	if(buttonDisabled):
		buttonState = "disabled"
	print(version_label.text +" "+ path_label.text + " Button ["+ buttonState +"]" )
	launch_button.disabled = buttonDisabled
	
	launch_button.button_down.connect(_on_launch_button_pressed)

func _on_launch_button_pressed() -> void:
	launch(pathText)
	print("button Pressed", Globals.closeOnLaunch)
	if(Globals.closeOnLaunch):
		get_tree().quit();

func launch(project_path: String) -> void:
	if executablePath != "":
		var project_godot_file = project_path.path_join("project.godot")
		var args = [project_godot_file]
		var output = []
		var process_info = OS.execute_with_pipe(executablePath, args)
		if process_info.size() == 0:
			print("Failed to launch Godot with project: %s" % project_godot_file)
		else:
			var pid = process_info["pid"]

			print("Launched Godot with project: %s" % project_godot_file)
	else:
		print("Executable path is not set.")
