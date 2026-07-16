import struct

final_bin = r'C:\Users\taoran\Desktop\cgo-test\main_nc_v5'

# Runtime output: gcdata= 0x400000d5d90
# Search for this 8-byte value in the binary
target = struct.pack('<Q', 0x400000d5d90)

with open(final_bin, 'rb') as f:
    data = f.read()

idx = data.find(target)
if idx >= 0:
    print(f'Found 0x400000d5d90 at file offset 0x{idx:X}')
    print(f'  -> Type struct start would be at file offset 0x{idx-32:X}')
    # Check if this is within .data.rel.ro
    # .data.rel.ro: file offset 0xA7780, size 0x70758
    if 0xA7780 <= idx-32 < 0xA7780 + 0x70758:
        print(f'  -> Within .data.rel.ro')
        offset_from_sec = (idx-32) - 0xA7780
        print(f'  -> Offset from sec[4] start: 0x{offset_from_sec:X}')
        # Check what VA this maps to
        va = 0xB7780 + offset_from_sec
        print(f'  -> VA: 0x{va:X}')
    else:
        print(f'  -> NOT in .data.rel.ro')
else:
    print(f'0x400000d5d90 NOT FOUND directly')

# Now, the compact GCData value is 0xA5D90 (an offset)
# When expanded by runtime: real_ptr = SOME_BASE + 0xA5D90
# If real_ptr = 0x400000d5d90, then:
# SOME_BASE = 0x400000d5d90 - 0xA5D90 = 0x400000D0000
#
# But 0xA5D90 + loadBias = 0xA5D90 + 0x40000000000 = 0x400000A5D90
# And 0x400000D5D90 - 0x400000A5D90 = 0x30000
# So the runtime adds an extra 0x30000 to the pointer!

print(f"\n=== Expansion offset analysis ===")
compact_gcdata = 0xA5D90
runtime_gcdata = 0x400000d5d90
load_bias = 0x40000000000

expected = compact_gcdata + load_bias
actual = runtime_gcdata
diff = actual - expected
print(f"Compact GCData value: 0x{compact_gcdata:X}")
print(f"Expected runtime ptr (compact + loadBias): 0x{expected:X}")
print(f"Actual runtime ptr: 0x{actual:X}")
print(f"DIFFERENCE: 0x{diff:X} ({diff})")

# What if the base is different?
# If runtime sees types at 0x400000E7780
# And compact GCData needs base = datap.rodata or something
print(f"\ndatap.types from runtime: 0x400000e7780")
# Try: GCData_runtime = datap.rodata + compact_gcdata
# rodata = 0x400000b5e80
# 0x400000b5e80 + 0xA5D90 = 0x400000BFC10 — not 0x400000D5D90
print(f"datap.types + compact_gcdata = 0x{0x400000e7780 + compact_gcdata:X}")
print(f"datap.types + compact_gcdata + 0x30000 = 0x{0x400000e7780 + compact_gcdata + 0x30000:X}")

# What if base = something at .data.rel.ro + 0x30000?
# Base = 0xB7780 + 0x30000 = 0xE7780 (this IS types!)
# GCData = types + compact_gcdata = 0xE7780 + 0xA5D90 = 0x18DD10
# With load bias: 0x40000000000 + 0x18DD10 = 0x4000018DD10 — WAY too large

# Check: is compact_gcdata = 0xA5D90 the offset from types section start?
# types section starts at sec[4] VA 0xB7780
# GCData_runtime = sec[4]_VA + compact_gcdata + loadBias
# = 0xB7780 + 0xA5D90 + 0x40000000000 = 0x400000D5D10...
# Hmm 0x400000D5D10 vs 0x400000D5D90, close but off by 0x80

# Wait, let me reread the raw GCData value from the real type data
with open(final_bin, 'rb') as f:
    # typelink[0] type at sec[4] + 0x5AC0
    f.seek(0xA7780 + 0x5AC0 + 32)  # GCData field at offset 32
    gcdata_raw = struct.unpack('<Q', f.read(8))[0]
    print(f"\nReal GCData raw value at sec[4]+0x5AC0+32: 0x{gcdata_raw:X}")

    # What's the actual runtime GCData for this type?
    # From ADP: gcdata= 0x400000d5c98 (v3) or 0x400000d5d90 (v4)
    # Let's check if 0xd5d90 makes sense
    # GCData_runtime = sec[4]_base_at_runtime + offset
    # sec[4]_base = 0x400000b7780 (loadBias + VA 0xB7780)
    # GCData_runtime = 0x400000b7780 + gcdata_raw
    if gcdata_raw < 0x100000:  # It's an offset
        expected2 = 0x400000b7780 + gcdata_raw
        print(f"Expected runtime GCData (sec[4]+offset): 0x{expected2:X}")
        print(f"Actual runtime GCData: 0x400000d5d90")
        diff2 = 0x400000d5d90 - expected2
        print(f"Diff: 0x{diff2:X}")

# Also check: the runtime types at 0xE7780 - what if it comes from sec[8] at a DIFFERENT offset?
# sec[8] in final binary: starts at file offset 0xBD260
# The runtime says types at VA 0xE7780 = file offset 0xD7780
# 0xD7780 - 0xBD260 = 0x1A520 (offset into sec[8])
#
# If Go's expansion code adds the WRONG base...
# Let me check: in the compact encoding (sec[8]), are there "fixup" offsets that map to sec[4]?
with open(final_bin, 'rb') as f:
    f.seek(0xBD260)
    sec8_data = f.read(0x5ac78)

# Look for the offset value 0xA5D90 within sec[8]
off_bytes = struct.pack('<I', 0xA5D90 & 0xFFFFFFFF)
idx2 = sec8_data.find(off_bytes)
if idx2 >= 0:
    print(f"\nFound offset 0xA5D90 in sec[8] at offset 0x{idx2:X}")
else:
    print(f"\nOffset 0xA5D90 NOT found in sec[8]")

# Actually, the real question: where does 0x5AC0 (typelink[0]) point WITHIN sec[8]?
# If types = sec[8] + 0x1A520, then types + 0x5AC0 = sec[8] + 0x1A520 + 0x5AC0 = sec[8] + 0x1FFE0
# Let me check what's at sec[8] + 0x1FFE0
with open(final_bin, 'rb') as f:
    f.seek(0xBD260 + 0x1FFE0)
    chunk = f.read(48)
print(f"\nsec[8] + 0x1FFE0 (types+0x5AC0 in sec[8]): {' '.join(f'{b:02X}' for b in chunk)}")
size_v = struct.unpack('<Q', chunk[0:8])[0]
ptr_v = struct.unpack('<Q', chunk[8:16])[0]
print(f"  Size_={size_v} PtrBytes={ptr_v} Kind={chunk[23]}")

# Also check what's at sec[4] + 0x5AC0
with open(final_bin, 'rb') as f:
    f.seek(0xA7780 + 0x5AC0)
    chunk2 = f.read(48)
print(f"\nsec[4] + 0x5AC0 (real type): {' '.join(f'{b:02X}' for b in chunk2)}")
size_v2 = struct.unpack('<Q', chunk2[0:8])[0]
ptr_v2 = struct.unpack('<Q', chunk2[8:16])[0]
print(f"  Size_={size_v2} PtrBytes={ptr_v2} Kind={chunk2[23]}")

# The MILLION dollar question: is sec[8] + 0x1FFE0 ALSO a valid type?
print(f"\n=== CRITICAL CHECK ===")
print(f"sec[4].typelink[0] (real) at file 0x{0xA7780+0x5AC0:X}: Size_={size_v2} Kind={chunk2[23]}")
print(f"sec[8]+0x1FFE0 (types+0x5AC0) at file 0x{0xBD260+0x1FFE0:X}: Size_={size_v} Kind={chunk[23]}")
if size_v == 8 and chunk[23] == 54:
    print("!!! BOTH locations have valid type data !!!")
    print("The compiler placed type data in BOTH sec[4] and sec[8]!")
    print("The runtime 'types' pointer points to the sec[8] copy.")
