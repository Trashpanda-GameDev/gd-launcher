extends VBoxContainer

@onready var v_project_container: VBoxContainer = $ScrollContainer/VProjectContainer
@export var projectNode: PackedScene

func _ready() -> void:
	# Connect the "versions_updated" signal from the versions container
	var versions_container = get_node("../AvailableVersionsContainer")
	versions_container.versions_updated.connect(_on_versions_updated)

func _on_versions_updated(editor_versions: Dictionary):
	populate_project_list(editor_versions)

func populate_project_list(editor_versions: Dictionary) -> void:
	clear_container(v_project_container)
	var contents = get_godot_projects_file_contents()
	var projectPaths = parse_project_paths(contents)
	projectPaths.reverse()
	
	for projectPath in projectPaths:
		add_project(projectPath, editor_versions)

func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

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
