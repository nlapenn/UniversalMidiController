# controller_colors.gd
extends Node

const MSG_COLORS := 0xCC
const LEN_COLORS := 0x10
const DEFAULT_COLOR := 19  # Grey
const COLORS_COUNT := 16

func build_controller_colors_packet(colors: Array) -> PackedByteArray:
	# colors: Array of ints (0..21) OR enums, anything int-convertible
	var vals: Array[int] = []
	vals.resize(COLORS_COUNT)

	for i in range(COLORS_COUNT):
		var v := DEFAULT_COLOR
		if i < colors.size() and colors[i] != null:
			# Force to int and clamp to a byte
			v = int(colors[i]) & 0xFF
		vals[i] = v

	var packet := PackedByteArray()
	packet.resize(2 + COLORS_COUNT)
	packet[0] = MSG_COLORS
	packet[1] = LEN_COLORS
	for i in range(COLORS_COUNT):
		packet[2 + i] = vals[i]
	return packet

func build_controller_colors_packet_with_xor(colors: Array) -> PackedByteArray:
	var pkt := build_controller_colors_packet(colors)
	var csum := 0
	for b in pkt:
		csum ^= int(b)
	pkt.append(csum & 0xFF)
	return pkt
