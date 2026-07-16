import struct

go_o = r'C:\Users\taoran\Desktop\cgo-test\linker_analysis\captured_link\go.o'

# Let's check section [4] .data.rel.ro (offset 0x8e8e0, size 0x15620)
# This is likely where the compact type metadata lives
# Go _type structure (simplified, go1.25):
#   Size_       uintptr (8 bytes) - offset 0
#   PtrBytes    uintptr (8 bytes) - offset 8
#   Hash        uint32  (4 bytes) - offset 16
#   TFlag       uint8   (1 byte)  - offset 20
#   Align_      uint8   (1 byte)  - offset 21
#   ... (some fields)
#   Kind_       uint8   (1 byte)  - offset ~24 (varies)
#   ... more fields
#   GCData      *byte   (8 bytes) - offset varies

# Let me check section 4 at offset 0x5AC0
with open(go_o, 'rb') as f:
    f.seek(0x8e8e0)
    sec4_data = f.read(0x15620)
    print(f'Section [4] size: {len(sec4_data)}')
    # Check at offset 0x5AC0
    off = 0x5AC0
    if off < len(sec4_data):
        chunk = sec4_data[off:off+64]
        print(f'Section[4] at 0x{off:X}: {" ".join(f"{b:02X}" for b in chunk[:32])}')
        # Try as type struct
        size = struct.unpack('<Q', chunk[0:8])[0]
        ptrbytes = struct.unpack('<Q', chunk[8:16])[0]
        print(f'  As type: Size_={size}, PtrBytes={ptrbytes}')

    # Search for pattern: Size_=8, PtrBytes=8 (0x0800000000000000 0x0800000000000000)
    # in little-endian: 08 00 00 00 00 00 00 00 08 00 00 00 00 00 00 00
    pattern = bytes([8,0,0,0,0,0,0,0, 8,0,0,0,0,0,0,0])
    idx = sec4_data.find(pattern)
    print(f'\nPattern Size_=8, PtrBytes=8 found at: 0x{idx:X}' if idx >= 0 else '\nPattern Size_=8, PtrBytes=8 NOT found in sec[4]')
    if idx >= 0:
        chunk = sec4_data[idx:idx+64]
        print(f'  {" ".join(f"{b:02X}" for b in chunk[:48])}')
        # Parse more fields
        tflag = chunk[20]
        align = chunk[21]
        print(f'  TFlag={tflag}, Align_={align}')
        # Try to find Kind_ - it's at different offsets in different Go versions
        # Let's print bytes 20-40
        print(f'  Bytes 20-40: {" ".join(f"{b:02X}" for b in chunk[20:40])}')

    # Also search section [8]
    f.seek(0xa43c0)
    sec8_data = f.read(0x5ac78)
    print(f'\nSection [8] size: {len(sec8_data)}')
    idx8 = sec8_data.find(pattern)
    print(f'Pattern Size_=8, PtrBytes=8 found at: 0x{idx8:X}' if idx8 >= 0 else 'Pattern Size_=8, PtrBytes=8 NOT found in sec[8]')
    if idx8 >= 0:
        chunk = sec8_data[idx8:idx8+64]
        print(f'  {" ".join(f"{b:02X}" for b in chunk[:48])}')
        print(f'  Bytes 20-40: {" ".join(f"{b:02X}" for b in chunk[20:40])}')

    # Let's also look at what's actually at sec4 offset 0 (beginning of section)
    print(f'\nSection[4] beginning: {" ".join(f"{b:02X}" for b in sec4_data[:48])}')
    # And check if it looks like pointers (x86 addresses would be 48-bit)
    # For arm64 SylixOS, addresses start with 0x4000...
    print(f'\nSection[4] end: {" ".join(f"{b:02X}" for b in sec4_data[-32:])}')
