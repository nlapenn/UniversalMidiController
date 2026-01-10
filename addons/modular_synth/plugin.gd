@tool
extends EditorPlugin

const AUTOLOAD_NAME := "SynthConstants"
const AUTOLOAD_PATH := "res://addons/modular_synth/core/synth_constants.gd"

func _enter_tree() -> void:
	# Make the UI addon self-contained: if the host project doesn't already have
	# SynthConstants configured as an autoload, install our copy.
	#
	# If the project already defines SynthConstants, we leave it alone.
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	# Only remove the autoload if we added it (i.e. it still points to our path).
	var key := "autoload/%s" % AUTOLOAD_NAME
	if ProjectSettings.has_setting(key):
		var entry := ProjectSettings.get_setting(key)
		# Godot stores autoload entries as dictionaries.
		if typeof(entry) == TYPE_DICTIONARY and entry.get("path", "") == AUTOLOAD_PATH:
			remove_autoload_singleton(AUTOLOAD_NAME)
