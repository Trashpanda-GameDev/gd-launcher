extends VBoxContainer

@onready var v_available_versions_container: VBoxContainer = $VBoxContainer2/ScrollContainer/VAvailableVersionsContainer
@onready var file_dialog: FileDialog = $FileDialog
@onready var select_root_folder_button: Button = $VBoxContainer/SelectRootFolderButton
@onready var selected_folder_label: Label = $VBoxContainer/SelectedFolderLabel

signal folder_selected(path: String)
signal versions_updated(editor_versions: Dictionary)

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
	var editor_versions = await populate_available_versions_list()
	emit_signal("versions_updated", editor_versions)

func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func populate_available_versions_list() -> Dictionary:
	var editor_versions = {}
	var editorFolder = await get_godot_editor_folder()
	selected_folder_label.text = editorFolder
	print("Scanning for editor versions....")
	editor_versions = search_for_godot_executables(editorFolder, editor_versions)
	print("\n")
	print("Populating version list...")
	# For each editor_version, create a label, set label text, and add label to v_available_versions_container
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
	print("\n\n")
	return editor_versions

func _on_folder_selected(path: String) -> void:
	emit_signal("folder_selected", path)

func get_godot_editor_folder() -> String:
	# check if selected folder is saved
	var saved_folder = Globals.config.get_value("settings", "godot_executable_parent", "")
	if saved_folder != "":
		print("Using saved folder: ", saved_folder)
		return saved_folder
	
	# prompt the user to select a root folder
	print("Enable Folder Selection...")
	file_dialog.visible = true
	print("Waiting for selection...")
	var selection = await (folder_selected)
	print("Selection: " + selection)
	
	# save the selected root folder
	Globals.config.set_value("settings","godot_executable_parent", selection)
	Globals.config.save("user://settings.cfg")
	print("\n")
	return selection

func search_for_godot_executables(parent_dir: String, editor_versions: Dictionary) -> Dictionary:
	print("Checking: ", parent_dir)
	var dir = DirAccess.open(parent_dir)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
	
		while file_name != "":
			if dir.current_is_dir():
				# Recursively search in subdirectories
				var sub_dir = parent_dir.path_join(file_name)
				editor_versions = search_for_godot_executables(sub_dir, editor_versions)
			elif is_godot_executable(parent_dir.path_join(file_name)):
				# Process the Godot executable file
				editor_versions = process_godot_executable(parent_dir, file_name, editor_versions)
	
			file_name = dir.get_next()
	
		dir.list_dir_end()
	
	return editor_versions

# Helper function to check if a file is a Godot executable
func is_godot_executable(file_path: String) -> bool:
	var isEXE = file_path.to_lower().ends_with(".exe")
	if(!isEXE):
		return false;
	
	var productName: String = get_exe_properties(file_path)["product_name"]
	var containsGodot = productName.containsn("godot")
	return containsGodot

func get_exe_properties(exe_path: String):
	var output = []
	var error = []
	
	# Get Product Version
	var version_command = "(Get-Item '"+exe_path+"').VersionInfo.ProductVersion"
	var version_exit_code = OS.execute("powershell.exe", ["-Command", version_command], output, true)
	
	if version_exit_code != 0:
		print("Error fetching product version: ", error)
		return
	
	var product_version = output[0].strip_edges()
	
	# Get Product Name
	output.clear()
	var name_command = "(Get-Item '"+exe_path+"').VersionInfo.ProductName"
	var name_exit_code = OS.execute("powershell.exe", ["-Command", name_command], output, true)
	
	if name_exit_code != 0:
		print("Error fetching product name: ", error)
		return
	
	var product_name = output[0].strip_edges()
	
	output.clear()
	var description_command = "(Get-Item '"+exe_path+"').VersionInfo.FileDescription"
	var desc_exit_code = OS.execute("powershell.exe", ["-Command", description_command], output, true)
	
	if desc_exit_code != 0:
		print("Error fetching product name: ", error)
		return
	
	var product_description = output[0].strip_edges()
	
	output.clear()
	var file_version_command = "(Get-Item '"+exe_path+"').VersionInfo.FileVersion"
	var file_version_exit_code = OS.execute("powershell.exe", ["-Command", file_version_command], output, true)
	
	if desc_exit_code != 0:
		print("Error fetching product name: ", error)
		return
	
	var product_file_version = output[0].strip_edges()
	
	#print("Product Description: ", product_description)
	#print("Product Name: ", product_name)
	#print("Product Version: ", product_version)
	#print("Product File Version: ", product_file_version)
	
	return {
		"product_description": product_description,
		"product_name": product_name,
		"product_version": product_version,
		"product_file_version": product_file_version
	}


func process_godot_executable(parent_dir: String, file_name: String, editor_versions: Dictionary) -> Dictionary:
	
	var properties = get_exe_properties(parent_dir.path_join(file_name));
	
	var version = properties["product_file_version"] # get_godot_version(file_name)
	var version_key = version # version.split("-")[0]  # Extract the version number without the suffix
	
	if not editor_versions.has(version):
		editor_versions[version] = {}
	
	if properties["product_name"].to_lower().find("console") != -1:
		editor_versions[version]["console"] = parent_dir.path_join(file_name)
	else:
		editor_versions[version]["core"] = parent_dir.path_join(file_name)
	
	return editor_versions

func get_godot_version(file_name: String) -> String:
	# Extract version from the file name
	var version_regex = RegEx.new()
	version_regex.compile("\\d+(?:\\.\\d+)+")
	var match = version_regex.search(file_name)
	if match:
		return match.get_string()  # Extract the version number without "v" and "-"
	else:
		return "Unknown"
