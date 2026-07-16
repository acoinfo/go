import struct

go_o = r'C:\Users\taoran\Desktop\cgo-test\linker_analysis\captured_link\go.o'
final_bin = r'C:\Users\taoran\Desktop\cgo-test\main_nc_v5'

# 1. Verify go.o section [4] contains proper types
with open(go_o, 'rb') as f:
    f.seek(0x8e8e0)
    sec4 = f.read(0x15620)

# typelink[0] = 0x5AC0 → go.o file offset 0x8e8e0 + 0x5AC0 = 0x943A0
off = 0x5AC0
raw = sec4[off:off+48]
print("=== go.o type at typelink[0] offset 0x5AC0 ===")
print(f"  Raw: {' '.join(f'{b:02X}' for b in raw)}")
size_ = struct.unpack('<Q', raw[0:8])[0]
ptrbytes = struct.unpack('<Q', raw[8:16])[0]
print(f"  Size_={size_} PtrBytes={ptrbytes} Kind={raw[23]} Align={raw[21]} TFlag={raw[20]}")
gcdata = struct.unpack('<Q', raw[32:40])[0]
print(f"  GCData=0x{gcdata:X}")

# 2. Now check: what section in the final binary corresponds to go.o section [4]?
# go.o section [4] is .data.rel.ro
# In the final binary, .data.rel.ro is at different offset

# The key question: did the linker preserve the CONTENT of .data.rel.ro?
# Let me search for the exact first 48 bytes of go.o sec[4] in the final binary
first48 = sec4[:48]
print(f"\n=== Searching for go.o sec[4] first 48 bytes in final binary ===")
with open(final_bin, 'rb') as f:
    final_data = f.read()
    idx = final_data.find(first48)
    if idx >= 0:
        print(f"  Found at offset 0x{idx:X}")
    else:
        print(f"  NOT FOUND!")

# 3. Search for the typelink[0] type bytes in final binary
type0_bytes = sec4[0x5AC0:0x5AC0+48]
idx2 = final_data.find(type0_bytes)
if idx2 >= 0:
    print(f"\ntypelink[0] type found at final binary offset 0x{idx2:X}")
else:
    print(f"\ntypelink[0] type NOT FOUND in final binary!")

# 4. What about section [8]? Does it match anything in final binary?
with open(go_o, 'rb') as f:
    f.seek(0xa43c0)
    sec8 = f.read(0x5ac78)

# Search for first 48 bytes of sec8 in final binary
sec8_first48 = sec8[:48]
idx3 = final_data.find(sec8_first48)
print(f"\n=== go.o sec[8] first 48 bytes in final binary ===")
if idx3 >= 0:
    print(f"  Found at offset 0x{idx3:X}")
else:
    # Try first 16 bytes
    sec8_first16 = sec8[:16]
    idx3b = final_data.find(sec8_first16)
    if idx3b >= 0:
        print(f"  First 16 bytes found at 0x{idx3b:X}")
    else:
        print(f"  NOT FOUND!")

# 5. Let's check: what IS at file offset 0xd7780?
# (This is where I calculated types should be)
# Let me look around that area for type-like content
print(f"\n=== Data around calculated types offset 0xD7780 ===")
with open(final_bin, 'rb') as f:
    f.seek(0xD7780)
    surrounding = f.read(256)
    # Check if any 8-byte sequence looks like Size_=8, PtrBytes=8
    for i in range(0, 200, 4):
        if i + 16 > len(surrounding): break
        val1 = struct.unpack('<Q', surrounding[i:i+8])[0]
        val2 = struct.unpack('<Q', surrounding[i+8:i+16])[0]
        if val1 == 8 and val2 == 8:
            print(f"  Size_=8,PtrBytes=8 at local offset 0x{i:X}")

# 6. Let me also check: what IS the content in final binary that matches section 4?
# The sec4 in go.o has 203 types with Size_=8, PtrBytes=8
# The same count should be in the final binary in .data.rel.ro at some offset

# Compute the mapping differently:
# go.o section [4] → final binary .data.rel.ro
# The linker should map sec[4] of go.o to somewhere in final's .data.rel.ro
# But the linker also adds data from other .o files (000000.o etc.)

# Let me find where the types landed by looking at the typelinks in final binary
# typelink is in section [5] of go.o
with open(go_o, 'rb') as f:
    f.seek(0xa3f00)  # .data.rel.ro.typelink
    typelink_data = f.read(0x474)

# These are offsets into the types section
# In the final binary, the same offset values should be used
# Let me find typelink data in the final binary
idx_tl = final_data.find(typelink_data)
if idx_tl >= 0:
    print(f"\n=== typelink data found at final binary offset 0x{idx_tl:X} ===")
else:
    # Search for first 16 bytes of typelink
    idx_tl2 = final_data.find(typelink_data[:16])
    if idx_tl2 >= 0:
        print(f"\ntypelink first 16 bytes at 0x{idx_tl2:X}")
    else:
        print(f"\ntypelink data NOT FOUND (possibly modified by linker)")

# Summary
print("\n=== SUMMARY ===")
print(f"go.o sec[4] (.data.rel.ro) size: 0x{len(sec4):X}")
print(f"go.o sec[8] (.data.rel.ro.local) size: 0x{len(sec8):X}")
print(f"types runtime address: 0x400000e7780")
print(f"types section size: 0x{len(sec4):X} (matches sec[4])")
print("The types appear to come from sec[4], but the linker has MODIFIED them")
