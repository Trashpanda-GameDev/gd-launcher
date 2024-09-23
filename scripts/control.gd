extends Control

@onready var v_available_versions_container: VBoxContainer = $AvailableVersionsContainer/ScrollContainer/VAvailableVersionsContainer
@onready var v_project_container: VBoxContainer = $ProjectsParent/ScrollContainer/VProjectContainer

@export var projectNode: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var editor_versions = populate_available_versions_list()
	populate_project_list(editor_versions)

func populate_available_versions_list() -> Dictionary:
	var editor_versions = {}
	var editorFolder = get_godot_editor_folder()
	editor_versions = search_for_godot_executables(editorFolder, editor_versions)

	# For each editor_version, create a label, set label text, and add label to v_available_versions_container
	for version_key in editor_versions.keys():
		var version_info = editor_versions[version_key]
		var core = version_info.get("core", "")
		var console = version_info.get("console", "")
		var label_text = version_key
		if core != "":
			label_text += " [core]"
		if console != "":
			label_text += " [console]"
		var label = Label.new()
		label.text = label_text
		v_available_versions_container.add_child(label)

	print(editor_versions)
	return editor_versions

func populate_project_list(editor_versions: Dictionary) -> void:
	var contents = get_godot_projects_file_contents()
	var projectPaths = parse_project_paths(contents)

	for projectPath in projectPaths:
		add_project(projectPath, editor_versions)

func add_project(projectPath: String, editor_versions: Dictionary) -> void:
	var projectEntry = projectNode.instantiate()
	var fileContents = get_godot_project_config(projectPath)
	var name = extract_project_name(fileContents)
	var version = extract_version_number(fileContents)
	
	if (version == "Unknown"):
		projectEntry.buttonDisabled = true;
	
	projectEntry.nameText = name
	projectEntry.pathText = projectPath
	projectEntry.versionText = version
	
	# Set the executable path for the project entry
	var executable_path = get_editor_path(version, editor_versions)
	projectEntry.executablePath = executable_path
	
	v_project_container.add_child(projectEntry)

func get_godot_editor_folder() -> String:
	var executable_path = OS.get_executable_path()
	var executable_dir = executable_path.get_base_dir()
	var parent_dir = executable_dir.get_base_dir()
	
	return parent_dir

# Function to search for Godot executables in a given directory and its subdirectories
func search_for_godot_executables(parent_dir: String, editor_versions: Dictionary) -> Dictionary:
	print("opening dir: ", parent_dir)
	var dir = DirAccess.open(parent_dir)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if dir.current_is_dir():
				# Recursively search in subdirectories
				var sub_dir = parent_dir.path_join(file_name)
				editor_versions = search_for_godot_executables(sub_dir, editor_versions)
			elif is_godot_executable(file_name):
				# Process the Godot executable file
				editor_versions = process_godot_executable(parent_dir, file_name, editor_versions)

			file_name = dir.get_next()

		dir.list_dir_end()
	
	return editor_versions

# Helper function to check if a file is a Godot executable
func is_godot_executable(file_name: String) -> bool:
	return file_name.to_lower().begins_with("godot") and file_name.to_lower().ends_with(".exe")

# Helper function to process a Godot executable file
func process_godot_executable(parent_dir: String, file_name: String, editor_versions: Dictionary) -> Dictionary:
	var version = get_godot_version(file_name)
	var version_key = version.split("-")[0]  # Extract the version number without the suffix
	
	if not editor_versions.has(version_key):
		editor_versions[version_key] = {}

	if file_name.to_lower().find("console") != -1:
		editor_versions[version_key]["console"] = parent_dir.path_join(file_name)
	else:
		editor_versions[version_key]["core"] = parent_dir.path_join(file_name)
	
	return editor_versions

func get_godot_version(file_name: String) -> String:
	# Extract version from the file name
	var version_regex = RegEx.new()
	version_regex.compile("v(\\d+\\.\\d+)-")
	var match = version_regex.search(file_name)
	if match:
		return match.get_string(1)  # Extract the version number without "v" and "-"
	else:
		return "Unknown"

func get_editor_path(version: String, editor_versions: Dictionary) -> String:
	if editor_versions.has(version):
		return editor_versions[version].get("core", "Version not found")
	else:
		return "Version not found"

func get_godot_project_config(path: String) -> String:
	var filePath = path.path_join("project.godot")
	var file = FileAccess.open(filePath, FileAccess.READ)
	var fileContents = file.get_as_text()
	file.close()
	return fileContents

func extract_version_number(config_contents: String) -> String:
	var version_regex = RegEx.new()
	version_regex.compile('config/features=PackedStringArray\\("([^"]+)"')
	var match = version_regex.search(config_contents)
	if match:
		return match.get_string(1)
	else:
		return "Unknown"

func extract_project_name(config_contents: String) -> String:
	var name_regex = RegEx.new()
	name_regex.compile('config/name="([^"]+)"')
	var match = name_regex.search(config_contents)
	if match:
		return match.get_string(1)
	else:
		return "Unknown Name"

func get_godot_projects_file_contents() -> String:
	var filePath = get_godot_config_path().path_join("projects.cfg")
	var file = FileAccess.open(filePath, FileAccess.READ)
	var fileContents = file.get_as_text()
	file.close()
	return fileContents

func get_godot_config_path() -> String:
	match OS.get_name():
		"Windows":
			return OS.get_environment("APPDATA").path_join("Godot")
		"Linux", "BSD":
			return "" # OS.get_environment("HOME").path_join(".config/godot")
		"OSX":
			return "" # OS.get_environment("HOME").path_join("Library/Application Support/Godot")
	return ""

func parse_project_paths(config_string: String) -> Array:
	var project_paths = []
	var lines = config_string.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			var path = line.substr(1, line.length() - 2)  # Remove the square brackets
			project_paths.append(path)
	return project_paths
