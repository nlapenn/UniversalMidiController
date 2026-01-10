extends RefCounted
class_name ModularSynthBlockSpecLoader

## Loads JSON block specs from disk, with simple caching and minimal validation.

var _cache: Dictionary = {} # path -> Dictionary

func load_spec(path: String) -> Dictionary:
	if path == "":
		return {}
	if _cache.has(path):
		return _cache[path]
	if !FileAccess.file_exists(path):
		push_error("ModularSynth: Spec file not found: %s" % path)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ModularSynth: Spec is not a JSON object: %s" % path)
		return {}

	# Minimal validation: keep this permissive so iteration is easy.
	for k in ["schema", "type", "title", "ports"]:
		if !parsed.has(k):
			push_error("ModularSynth: Spec missing '%s': %s" % [k, path])
			return {}
	if !parsed.has("params"):
		parsed["params"] = []

	_cache[path] = parsed
	return parsed
