extends VBoxContainer

@onready var v_available_versions_container: VBoxContainer = $VBoxContainer2/ScrollContainer/VAvailableVersionsContainer
@onready var file_dialog: FileDialog = $FileDialog
@onready var select_root_folder_button: Button = $VBoxContainer/SelectRootFolderButton
@onready var selected_folder_label: Label = $VBoxContainer/SelectedFolderLabel

signal folder_selected(path: String)
signal versions_updated(editor_versions: Dictionary)

const VERSIONS_FILE = "user://versions.json"
const HASH_FILE = "user://folder_hash.txt"

func _ready() -> void:
	file_dialog.dir_selected.connect(_on_folder_selected)
	select_root_folder_button.button_down.connect(reselect_root_folder)
	update_versions_list()

func reselect_root_folder():
	Globals.config.set_value("settings", "godot_executable_parent", null)
	Globals.config.save("user://settings.cfg")
	update_versions_list()

func update_versions_list():
	clear_container(v_available_versions_container)
	var editor_versions = await get_versions_list()
	emit_signal("versions_updated", editor_versions)

func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func get_versions_list() -> Dictionary:
	var editor_versions = {}
	var editorFolder = await get_godot_editor_folder()
	selected_folder_label.text = editorFolder

	var current_hash_dict = hash_folder_structure(editorFolder)
	var saved_hash_dict = load_saved_hash_dict()

	if current_hash_dict == saved_hash_dict:
		editor_versions = load_versions_list()
		if editor_versions.size() > 0:
			populate_versions_container(editor_versions)
			return editor_versions

	editor_versions = await populate_available_versions_list(current_hash_dict, saved_hash_dict)
	save_versions_list(editor_versions)
	save_hash_dict(current_hash_dict)
	return editor_versions

func populate_available_versions_list(current_hash_dict: Dictionary, saved_hash_dict: Dictionary) -> Dictionary:
	var editor_versions = {}
	print("Scanning for editor versions....")
	editor_versions = search_for_godot_executables(selected_folder_label.text, editor_versions, current_hash_dict, saved_hash_dict)
	print("\n")
	print("Populating version list...")
	populate_versions_container(editor_versions)
	print("\n\n")
	return editor_versions

func populate_versions_container(editor_versions: Dictionary) -> void:
	for version_key in editor_versions.keys():
		var version_info = editor_versions[version_key]
		var core = version_info.get("core", "")
		var console = version_info.get("console", "")
		var label_text = version_key
		if core != "":
			print(version_key + " [core]:    ", core)
			label_text += " [core]"
		if console != "":
			print(version_key + " [console]: ", console)
			label_text += " [console]"
		var label = Label.new()
		label.text = label_text
		v_available_versions_container.add_child(label)

func _on_folder_selected(path: String) -> void:
	emit_signal("folder_selected", path)

func get_godot_editor_folder() -> String:
	var saved_folder = Globals.config.get_value("settings", "godot_executable_parent", "")
	if saved_folder != "":
		print("Using saved folder: ", saved_folder)
		return saved_folder
	
	print("Enable Folder Selection...")
	file_dialog.visible = true
	print("Waiting for selection...")
	var selection = await (folder_selected)
	print("Selection: " + selection)
	
	Globals.config.set_value("settings","godot_executable_parent", selection)
	Globals.config.save("user://settings.cfg")
	print("\n")
	return selection

func search_for_godot_executables(parent_dir: String, editor_versions: Dictionary, current_hash_dict: Dictionary, saved_hash_dict: Dictionary) -> Dictionary:
	print("Checking: ", parent_dir)
	var dir = DirAccess.open(parent_dir)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
	
		while file_name != "":
			var full_path = parent_dir.path_join(file_name)
			if dir.current_is_dir():
				editor_versions = search_for_godot_executables(full_path, editor_versions, current_hash_dict, saved_hash_dict)
			elif not dir.current_is_dir():
				if current_hash_dict[full_path] != saved_hash_dict.get(full_path, ""):
					if is_godot_executable(full_path):
						editor_versions = process_godot_executable(parent_dir, file_name, editor_versions)
	
			file_name = dir.get_next()
	
		dir.list_dir_end()
	
	return editor_versions

func is_godot_executable(file_path: String) -> bool:
	var isEXE = file_path.to_lower().ends_with(".exe")
	if(!isEXE):
		return false;
	
	var props = get_exe_properties(file_path);
	if(!props):
		return false;
	
	var productName = props["product_name"]
	if(!productName):
		return false;
	var containsGodot = productName.containsn("godot")
	return containsGodot

func get_exe_properties(exe_path: String) -> Dictionary:
	var output = []
	var error = []
	
	var script = "$exe = Get-Item '" + exe_path + "'; "
	script += "$properties = @{"
	script += "product_version = $exe.VersionInfo.ProductVersion; "
	script += "product_name = $exe.VersionInfo.ProductName; "
	script += "product_description = $exe.VersionInfo.FileDescription; "
	script += "product_file_version = $exe.VersionInfo.FileVersion}; "
	script += "$properties | ConvertTo-Json"
	
	var exit_code = OS.execute("powershell.exe", ["-Command", script], output, true)
	
	if exit_code != 0:
		print("Error fetching properties: ", error)
		return {}
	
	var json_string = ""
	for line in output:
		json_string += line
	
	var json = JSON.parse_string(json_string)
	if json == null:
		print("Error parsing JSON output: ", output)
		return {}
	
	return json

func process_godot_executable(parent_dir: String, file_name: String, editor_versions: Dictionary) -> Dictionary:
	
	var properties = get_exe_properties(parent_dir.path_join(file_name));
	
	var version = get_godot_version(properties["product_file_version"])
	
	if not editor_versions.has(version):
		editor_versions[version] = {}
	
	if properties["product_name"].to_lower().find("console") != -1:
		editor_versions[version]["console"] = parent_dir.path_join(file_name)
	else:
		editor_versions[version]["core"] = parent_dir.path_join(file_name)
	
	return editor_versions

func get_godot_version(file_name: String) -> String:
	var version_regex = RegEx.new()
	version_regex.compile("\\d+(?:\\.\\d+)+")
	var match = version_regex.search(file_name)
	if match:
		return match.get_string()
	else:
		return "Unknown"

func hash_folder_structure(folder_path: String) -> Dictionary:
	var dir = DirAccess.open(folder_path)
	if not dir:
		return {}
	
	var hash_dict = {}
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = folder_path.path_join(file_name)
		if dir.current_is_dir():
			var sub_hash_dict = hash_folder_structure(full_path)
			for key in sub_hash_dict.keys():
				hash_dict[key] = sub_hash_dict[key]
			hash.update(full_path.to_utf8_buffer())
			hash.update(sub_hash_dict[full_path].to_utf8_buffer())
		else:
			var file_hash = hash_file_contents(full_path)
			hash_dict[full_path] = file_hash.hex_encode()
			hash.update(full_path.to_utf8_buffer())
			hash.update(file_hash)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	hash_dict[folder_path] = hash.finish().hex_encode()
	return hash_dict

func hash_file_contents(file_path: String) -> PackedByteArray:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return PackedByteArray()
	
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	
	while not file.eof_reached():
		var chunk = file.get_buffer(1024)
		hash.update(chunk)
	
	file.close()
	return hash.finish()

func load_saved_hash_dict() -> Dictionary:
	var file = FileAccess.open(HASH_FILE, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			return json.data
	return {}

func save_hash_dict(hash_dict: Dictionary) -> void:
	var file = FileAccess.open(HASH_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(hash_dict))
	file.close()

func load_versions_list() -> Dictionary:
	var file = FileAccess.open(VERSIONS_FILE, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			return json.data
	return {}

func save_versions_list(editor_versions: Dictionary) -> void:
	var file = FileAccess.open(VERSIONS_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(editor_versions))
	file.close()
