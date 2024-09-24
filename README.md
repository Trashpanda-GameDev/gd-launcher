# GD Launcher
The project currently only works for windows.
The idea is that the launcher detects which versions of godot you have installed, and then when the launch button of a project is pressed the project should start with that version of Godot.
This should result in less switching between versions because of opening the wrong initial godot version.

## how to
1. Launch the project.
2. Select the root folder under which you have your godot executables.
    - this launcher assumes that you have all your godot versions centralized under 1 folder, They can be in subfolders but they should in the end have 1 root parent folder.
3. The launcher starts scanning the root folder and subfolder for installed executables. Then populates the lists of projects and godot versions available.
4. Launch a project with the launch button. and the project will launch with the correct Godot version if you have it installed.