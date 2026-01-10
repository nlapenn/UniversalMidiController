# Modular Synth (UI addon)

This addon extracts the GraphEdit-based patch editor UI from the demo project into a drop-in scene.

## Key pieces

- `ui/synth_graph_editor.tscn` + `.gd`: the portable GraphEdit UI
- `core/engine_adapter.gd`: forwards calls to your synth backend node
- `core/block_registry.gd`: maps block types -> block scenes
- `core/synth_constants.gd`: provides `SynthConstants` (installed as an autoload when the plugin is enabled)

## Minimal usage

1. Copy `addons/modular_synth` into your project.
2. Enable the plugin: **Project Settings → Plugins → Modular Synth (UI)**.
3. Add `ModularSynthEngineAdapter` somewhere and set `backend_path` to your synth backend wrapper.
4. Instance `ui/synth_graph_editor.tscn` and set:
   - `engine_adapter_path`
   - `registry` (either your own `ModularSynthBlockRegistry` Resource, or `ModularSynthExampleRegistry.new()` for the demo)
