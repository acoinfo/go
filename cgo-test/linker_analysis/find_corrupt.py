import struct

final_bin = r'C:\Users\taoran\Desktop\cgo-test\main_nc_v5'

# From ADP v4 runtime output:
# loadBias = 0x40000000000
# types = 0x400000e7780
# File VA = types - loadBias = 0xe7780

# From readelf -S main_nc_v5:
# .data.rel.ro at VA 0xb7780, file offset 0xa7780
# types at VA 0xe7780 → file offset = 0xe7780 - 0xb7780 + 0xa7780 = 0xd7780
data_rel_ro_va = 0xb7780
data_rel_ro_file = 0xa7780

types_va = 0xe7780
types_file = types_va - data_rel_ro_va + data_rel_ro_file
print(f"types at file offset: 0x{types_file:X}")

# Also compute etypes
# etypes = 0x400000fcda0 → file VA = 0xfcda0 → file off = 0xfcda0 - 0xb7780 + 0xa7780
etypes_va = 0xfcda0
etypes_file = etypes_va - data_rel_ro_va + data_rel_ro_file
print(f"etypes at file offset: 0x{etypes_file:X}")
types_size = etypes_file - types_file
print(f"types section size: {types_size} (0x{types_size:X})")

# Now read types data from the final binary
with open(final_bin, 'rb') as f:
    f.seek(types_file)
    types_data = f.read(types_size)

print(f"\nRead {len(types_data)} bytes of types data")

# Parse and find the typelinks types
# typelink[0] offset from ADP = 23232 (0x5AC0)
# From go.o, typelinks are in section [5] at file offset 0xa3f00

# Let me first look at types[0] (offset 0 in types section)
print("\n=== types[0] (offset 0) ===")
raw = types_data[0:48]
print(f"  Raw: {' '.join(f'{b:02X}' for b in raw[:32])}")
print(f"  Raw: {' '.join(f'{b:02X}' for b in raw[32:48])}")

# Parse
size_ = struct.unpack('<Q', raw[0:8])[0]
ptrbytes = struct.unpack('<Q', raw[8:16])[0]
hash_ = struct.unpack('<I', raw[16:20])[0]
tflag = raw[20]
align = raw[21]
fieldalign = raw[22]
kind = raw[23]
equal = struct.unpack('<Q', raw[24:32])[0]
gcdata = struct.unpack('<Q', raw[32:40])[0]
str_off = struct.unpack('<I', raw[40:44])[0]
ptrto = struct.unpack('<I', raw[44:48])[0]
print(f"  Size_={size_} PtrBytes={ptrbytes} Kind={kind} TFlag={tflag} Align={align}")
print(f"  GCData=0x{gcdata:X} Str={str_off}")

# Now check type at offset 0x5AC0 (typelink[0])
print(f"\n=== types[0x5AC0] (typelink[0]) ===")
off = 0x5AC0
raw = types_data[off:off+48]
size_ = struct.unpack('<Q', raw[0:8])[0]
ptrbytes = struct.unpack('<Q', raw[8:16])[0]
hash_ = struct.unpack('<I', raw[16:20])[0]
tflag = raw[20]
align = raw[21]
fieldalign = raw[22]
kind = raw[23]
equal = struct.unpack('<Q', raw[24:32])[0]
gcdata = struct.unpack('<Q', raw[32:40])[0]
str_off = struct.unpack('<I', raw[40:44])[0]
ptrto = struct.unpack('<I', raw[44:48])[0]
print(f"  Raw: {' '.join(f'{b:02X}' for b in raw)}")
print(f"  Size_={size_} PtrBytes={ptrbytes} Kind={kind} TFlag={tflag} Align={align}")
print(f"  GCData=0x{gcdata:X} Str={str_off}")

# Now: are there ANY types with PtrBytes=2 or Kind=0 or GCData=0x40?
print("\n=== Scanning ALL types for corruption ===")
corrupt = []
for off in range(0, len(types_data) - 48, 8):
    raw = types_data[off:off+48]
    size_ = struct.unpack('<Q', raw[0:8])[0]
    ptrbytes = struct.unpack('<Q', raw[8:16])[0]
    kind = raw[23]
    align = raw[21]
    gcdata = struct.unpack('<Q', raw[32:40])[0]

    # Check for signs of corruption
    is_type = (size_ > 0 and size_ < 0x100000 and ptrbytes <= size_ and kind < 64 and align <= 64)
    if not is_type:
        continue

    # Check for specific corruption patterns
    if ptrbytes == 2 and ptrbytes < size_ and kind == 0:
        corrupt.append((off, size_, ptrbytes, kind, align, gcdata))
        print(f"  CORRUPT at 0x{off:X}: Size_={size_} PtrBytes={ptrbytes} Kind={kind} Align={align} GCData=0x{gcdata:X}")
    elif gcdata == 0x40:
        corrupt.append((off, size_, ptrbytes, kind, align, gcdata))
        print(f"  GCData=0x40 at 0x{off:X}: Size_={size_} PtrBytes={ptrbytes} Kind={kind} Align={align}")

if not corrupt:
    print("  No corrupted types found in on-disk binary!")

# Also check: the types in the runtime are "expanded" from compact form
# The compact types section might be different from what the runtime uses
# Let me look for the compact type format
# In Go, types at runtime are at the address stored in moduledata.types
# They should be the expanded format already

# Let me check if the data at types_file matches go.o section [8] at a similar offset
print("\n=== Cross-check with go.o ===")
go_o = r'C:\Users\taoran\Desktop\cgo-test\linker_analysis\captured_link\go.o'
with open(go_o, 'rb') as f:
    # Section [8] is at file offset 0xa43c0
    # types are at offset 0x433c0 within section [8]
    f.seek(0xa43c0)
    sec8 = f.read(0x5ac78)

    # Print first 48 bytes of sec8 (where types should start)
    print(f"go.o sec[8] start: {' '.join(f'{b:02X}' for b in sec8[:48])}")

    # Compare with final binary types
    print(f"Final types start: {' '.join(f'{b:02X}' for b in types_data[:48])}")

    if sec8[:48] == types_data[:48]:
        print("  MATCH!")
    else:
        print("  DIFFERENT! Linker changed the data!")
        # Show the differences
        for i in range(48):
            if sec8[i] != types_data[i]:
                print(f"    Byte {i}: go.o={sec8[i]:02X} final={types_data[i]:02X}")
