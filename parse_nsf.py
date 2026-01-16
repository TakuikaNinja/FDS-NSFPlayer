#!/usr/bin/env python3
import sys, getopt

def parse_nsf_header(header):
	min_addr = 0x8000
	max_addr = 0xDFFF
	
	identifier = "".join([chr(x) for x in header[:0x05]])
	assert identifier == 'NESM\x1A', "Not an NSF file"
	
	version = header[0x05]
	assert version > 0, "NSF version must be 1 or higher"
	if version == 0x02:
		print("NSF2 file detected")
		nsf2_flags = header[0x7C]
		print(f"NSF2 features: %{nsf2_flags:08b}")
		if nsf2_flags != 0:
			print("WARNING: NSF2 features detected, songs may not play correctly")
	
	data_size = header[0x7D] + (header[0x7E] << 8) + (header[0x7F] << 16)
	if data_size > 0:
		print(f"NSF data size: ${data_size:06x}")
	assert data_size <= max_addr + 1 - min_addr, "NSF data is too large"
	
	load_addr = header[0x08] + (header[0x09] << 8)
	print(f"load address: ${load_addr:04x}")
	assert load_addr >= min_addr and load_addr <= max_addr, "load address should be within $8000-$dfff"
	init_addr = header[0x0A] + (header[0x0B] << 8)
	print(f"init address: ${init_addr:04x}")
	assert init_addr >= min_addr and init_addr <= max_addr, "init address should be within $8000-$dfff"
	play_addr = header[0x0C] + (header[0x0D] << 8)
	print(f"play address: ${play_addr:04x}")
	assert play_addr >= min_addr and play_addr <= max_addr, "play address should be within $8000-$dfff"
	
	ntsc_period = header[0x6E] + (header[0x6F] << 8)
	ntsc_speed = 1000000 / ntsc_period
	pal_period = header[0x78] + (header[0x79] << 8)
	pal_speed = 1000000 / pal_period
	
	# prefer NTSC
	target = 60
	speed = ntsc_speed
	
	region = header[0x7A]
	if region == 0x01:
		print("WARNING: PAL setting detected, songs may play faster than intended")
		target = 50
		speed = pal_speed
	print(f"playback rate: {speed:.3f}")
	assert round(speed) == target, "nonstandard speeds are not supported"
	
	bankswitch_init = header[0x70:0x78]
	for i in bankswitch_init:
		assert i == 0, "NSF cannot use bankswitching"
	
	expansions = header[0x7B]
	for i in range(8):
		if i == 2:
			continue
		assert expansions & (1 << i) == 0, "NSF cannot use expansion audio other than FDS"
	return load_addr, data_size

def main(in_filename):
	out = bytearray()
	with open(in_filename, "rb") as in_file:
		data = in_file.read(0x80)
	load_addr, data_size = parse_nsf_header(data)
	with open("nsfdata.asm", "w") as out_file:
		out_str = f'.define NSFFile "{in_filename}"\nNSFLoad := ${load_addr:04x}\n'
		if data_size > 0:
			out_str += f"NSFDataSize := ${data_size:06x}\n"
		#print(out_str)
		out_file.write(out_str)

if __name__ == "__main__":
	size = len(sys.argv)
	if size == 2:
		main(sys.argv[1])
	else:
		print("Usage: parse_nsf.py <input_file>")
	
