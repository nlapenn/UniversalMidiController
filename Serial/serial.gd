extends Node

@export var poll_interval := 0.02 # 20ms is plenty
var _accum := 0.0

var serial: GdSerial
signal controller_event(controller: int, delta: int, pushed: bool)
signal nav_event(action: String, pressed: bool) # Up/Down/Left/Right/Select etc.

var debug_led = 0
var debug_red = 255
var debug_blue = 255
var debug_green = 255
var debug_brightness = 255

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create serial instance
	serial = GdSerial.new()
	
	# List available ports
	print("Available ports:")
	var ports = serial.list_ports()
	for i in range(ports.size()):
		var port_info = ports[i]
		print("- ", port_info["port_name"], " (", port_info["port_type"], ")")
		
	# Configure and open port
	# serial.set_port("/dev/ttyACM0")  # Adjust for your system RPI
	serial.set_port("Com5")
	serial.set_baud_rate(115200)
	serial.set_timeout(1000)
	
	if serial.open():
		print("Port opened successfully!")


func _process(delta: float) -> void:
	_accum += delta
	if _accum < poll_interval:
		return
	_accum = 0.0
	
	if serial == null or not serial.is_open():
		return
	
	# Drain all available complete lines this tick
	# readline() blocks only up to timeout; so only call it when bytes_available > 0
	while serial.bytes_available() > 0:
		var line := serial.readline()
		if line == null:
			break
		line = line.strip_edges()
		if line.is_empty():
			continue
			
		_parse_line(line)

func _parse_line(line: String) -> void:
	# Example: "Controller: 3, Delta: -1, Pushed: false"
	if line.begins_with("Controller:"):
		var ctrl := _extract_int(line, "Controller:")
		var d := _extract_int(line, "Delta:")
		var pushed := _extract_bool(line, "Pushed:")
		emit_signal("controller_event", ctrl, d, pushed)
		return

	# Example: "Up: Pressed" / "Down: Released"
	# (also works for Left/Right/Select)
	if line.find(":") != -1:
		var parts := line.split(":", false, 2)
		if parts.size() == 2:
			var action := parts[0].strip_edges()
			var state := parts[1].strip_edges().to_lower()
			if state == "pressed" or state == "released":
				emit_signal("nav_event", action, state == "pressed")
				return
				
	# fallback debug
	print("Serial unknown:", line)

func _extract_int(s: String, key: String) -> int:
	var i := s.find(key)
	if i == -1:
		return 0
	var sub := s.substr(i + key.length()).strip_edges()
	# sub starts like "3, Delta: -1, Pushed: false"
	var end := sub.find(",")
	#var token := (end == -1) ? sub : sub.substr(0, end)
	var token := sub if (end == -1) else sub.substr(0, end)
	return int(token.strip_edges())

func _extract_bool(s: String, key: String) -> bool:
	var i := s.find(key)
	if i == -1:
		return false
	var sub := s.substr(i + key.length()).strip_edges().to_lower()
	# sub starts like "false" or "false, ..."
	var end := sub.find(",")
	#var token := (end == -1) ? sub : sub.substr(0, end)
	var token := sub if (end == -1) else sub.substr(0, end)
	token = token.strip_edges()
	return token == "true"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Quit request received. Doing cleanup/saving...")
		# Add your saving or cleanup code here
		serial.close()
		
		# After cleanup, manually quit the application
		get_tree().quit()
		
func set_encoder_colors(colors16: Array):
	print("set_encoder_colors")
	var packet := ControllerColors.build_controller_colors_packet(colors16)
	serial.write(packet)
	
func send_controller_colors_enum(colors16: Array) -> bool:
	if serial == null or not serial.is_open():
		push_warning("Serial not open; cannot send controller colors")
		return false

	var vals := []
	vals.resize(16)

	# colors16 is expected to contain 16 ints (enum values 0..255)
	for i in range(16):
		var v := 19 # default Grey (match your enum index if different)
		if i < colors16.size():
			v = int(colors16[i]) & 0xFF
		vals[i] = v

	var packet := PackedByteArray()
	packet.append(0xCC)
	packet.append(0x10)
	for v in vals:
		packet.append(v)

	# Debug once if needed:
	# print("TX colors: ", packet.hex_encode())

	return serial.write(packet)
	
func _on_button_pressed() -> void:
	#send_debug_led_rgb(debug_led, debug_red, debug_green, debug_blue, debug_brightness)
	var encoder_colors = []
	for i in range(16):
		encoder_colors.append(randi() * 15)
	set_encoder_colors(encoder_colors)
	

func send_debug_led_rgb(controller_index: int, r: int, g: int, b: int, brightness: int = 255) -> bool:
	if serial == null or not serial.is_open():
		push_warning("Serial not open; cannot send debug LED")
		return false

	controller_index = clamp(controller_index, 0, 15)
	r = clamp(r, 0, 255)
	g = clamp(g, 0, 255)
	b = clamp(b, 0, 255)
	brightness = clamp(brightness, 0, 255)

	var packet := PackedByteArray([
		0xCE, 0x05,
		controller_index & 0xFF,
		r & 0xFF,
		g & 0xFF,
		b & 0xFF,
		brightness & 0xFF
	])
	
	print(packet)

	return serial.write(packet)


func send_debug_led0_rgb(r: int, g: int, b: int, brightness: int = 255) -> bool:
	print("Sending packet: ", r, ", ", g, ", ", b, ", ", brightness)
	return send_debug_led_rgb(debug_led, r, g, b, brightness)


func _on_color_picker_button_color_changed(color: Color) -> void:
	debug_red = color.r * 255
	debug_green = color.g * 255
	debug_blue = color.b * 255
	#send_debug_led0_rgb(debug_red, debug_green, debug_blue, debug_brightness)

func _on_h_slider_value_changed(value: float) -> void:
	debug_brightness = clamp(int(value), 0, 255)
	#send_debug_led0_rgb(debug_red, debug_green, debug_blue, debug_brightness)


func _on_spin_box_value_changed(value: float) -> void:
	debug_led = int(value)
