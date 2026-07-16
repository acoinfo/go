import struct

go_o = r'C:\Users\taoran\Desktop\cgo-test\linker_analysis\captured_link\go.o'
final_bin = r'C:\Users\taoran\Desktop\cgo-test\main_nc_v5'

# Parse _type at a given offset
def parse_type(data, off):
    """Parse compact _type at offset within data, return dict"""
    if off + 48 > len(data):
        return None
    b = data[off:off+48]
    size_    = struct.unpack('<Q', b[0:8])[0]
    ptrbytes = struct.unpack('<Q', b[8:16])[0]
    hash_    = struct.unpack('<I', b[16:20])[0]
    tflag    = b[20]
    align_   = b[21]
    fieldalign = b[22]
    kind_    = b[23]
    equal    = struct.unpack('<Q', b[24:32])[0]
    gcdata   = struct.unpack('<Q', b[32:40])[0]
    str_off  = struct.unpack('<I', b[40:44])[0]
    ptrto    = struct.unpack('<I', b[44:48])[0]
    return {
        'off': off, 'Size_': size_, 'PtrBytes': ptrbytes,
        'Hash': hash_, 'TFlag': tflag, 'Align_': align_,
        'FieldAlign_': fieldalign, 'Kind_': kind_,
        'Equal': equal, 'GCData': gcdata, 'Str': str_off, 'PtrToThis': ptrto
    }

# Read section [4] from go.o
with open(go_o, 'rb') as f:
    f.seek(0x8e8e0)
    sec4 = f.read(0x15620)

# Find all types with Size_=8, PtrBytes=8
print("=== go.o Section [4] Size_=8,PtrBytes=8 types ===")
pattern = bytes([8,0,0,0,0,0,0,0, 8,0,0,0,0,0,0,0])
idx = 0
found = []
while True:
    idx = sec4.find(pattern, idx)
    if idx < 0:
        break
    t = parse_type(sec4, idx)
    if t and t['Size_'] < 0x1000 and t['PtrBytes'] < 0x1000:  # sanity check
        found.append(t)
        if len(found) <= 5:
            print(f"  +{idx:05X}: Kind={t['Kind_']} Align={t['Align_']} GCData=0x{t['GCData']:X} Str={t['Str']} TFlag={t['TFlag']}")
    idx += 1

print(f"  Total found: {len(found)}")

# Now look at the specific type that gets corrupted (the one NOT in typelinks)
# We know that typlink[0]=0x5AC0 and our types at 0x3DC0 also match
# Let's find the ChanType.Elem type that causes the crash
# The corrupted type has: Kind=0, Size=8, PtrBytes=2 (before fix), Align_=0
# After fixing: Kind=0, Size=8, PtrBytes=8, Align_=8
# Let me search for PtrBytes=2 near known good types in the corrupted region

# First, let me check the final binary at the same location
# In the final binary, section .data.rel.ro is at offset 0xa7780 (from readelf)
with open(final_bin, 'rb') as f:
    f.seek(0xa7780)
    final_data = f.read(0x70758)

# Search for pattern Size_=8, PtrBytes=8 in final binary
pattern = bytes([8,0,0,0,0,0,0,0, 8,0,0,0,0,0,0,0])
idx_final = 0
found_final = []
while True:
    idx_final = final_data.find(pattern, idx_final)
    if idx_final < 0:
        break
    t = parse_type(final_data, idx_final)
    if t and t['Size_'] < 0x1000 and t['PtrBytes'] < 0x1000:
        found_final.append(t)
    idx_final += 1

print(f"\n=== Final binary Size_=8,PtrBytes=8 types: {len(found_final)} ===")

# Now find the corrupted type: Kind=0 or PtrBytes=2
print("\n=== Searching for corrupted types in final binary ===")
# Search for any type with abnormal PtrBytes
idx_check = 0
# Use a broader pattern: just Size_=8
corrupt_count = 0
normal_count = 0
while idx_check < len(final_data) - 48:
    b = final_data[idx_check:idx_check+8]
    size_val = struct.unpack('<Q', b)[0]
    if size_val == 8 and size_val < 0x100:
        # Might be a type, check PtrBytes
        ptrbytes = struct.unpack('<Q', final_data[idx_check+8:idx_check+16])[0]
        kind = final_data[idx_check+23]
        align = final_data[idx_check+21]
        gcdata = struct.unpack('<Q', final_data[idx_check+32:idx_check+40])[0]
        equal = struct.unpack('<Q', final_data[idx_check+24:idx_check+32])[0]

        if ptrbytes == 2 and kind == 0:
            print(f"  CORRUPTED at 0x{idx_check:X}: Size_={size_val} PtrBytes={ptrbytes} Kind={kind} Align={align} GCData=0x{gcdata:X} Equal=0x{equal:X}")
            corrupt_count += 1
        elif ptrbytes == 8:
            normal_count += 1
    idx_check += 8

print(f"  Normal types: {normal_count}, Corrupted: {corrupt_count}")

# Now find the SAME offset in go.o and compare
# The corrupted type in final binary should correspond to an offset in go.o
# Let me search for the same pattern in go.o with PtrBytes=2
print("\n=== Checking go.o for PtrBytes=2 ===")
idx_go = 0
while idx_go < len(sec4) - 48:
    b = sec4[idx_go:idx_go+8]
    size_val = struct.unpack('<Q', b)[0]
    if size_val == 8:
        ptrbytes = struct.unpack('<Q', sec4[idx_go+8:idx_go+16])[0]
        if ptrbytes == 2:
            kind = sec4[idx_go+23]
            align = sec4[idx_go+21]
            gcdata = struct.unpack('<Q', sec4[idx_go+32:idx_go+40])[0]
            print(f"  go.o at 0x{idx_go:X}: Size_={size_val} PtrBytes={ptrbytes} Kind={kind} Align={align} GCData=0x{gcdata:X}")
            # Print full 48 bytes
            print(f"    Raw: {' '.join(f'{b:02X}' for b in sec4[idx_go:idx_go+48])}")
    idx_go += 8

print("\nDone.")
