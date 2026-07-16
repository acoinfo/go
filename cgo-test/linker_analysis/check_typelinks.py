import struct

go_o = r'C:\Users\taoran\Desktop\cgo-test\linker_analysis\captured_link\go.o'

with open(go_o, 'rb') as f:
    f.seek(0xa3f00)
    data = f.read(0x474)
    entries = struct.unpack('<' + 'I' * (len(data)//4), data)
    print(f'Total typelink entries: {len(entries)}')
    for i in range(min(10, len(entries))):
        print(f'  typelink[{i}] = 0x{entries[i]:05X} ({entries[i]})')
    print(f'  Min offset: 0x{min(entries):X}')
    print(f'  Max offset: 0x{max(entries):X}')
    bad = [e for e in entries if e > 0x5AC78]
    print(f'  Out-of-range entries: {len(bad)}')

    # Now look at the actual type data for type[0] at offset 0x5AC0 in section [8]
    # Section [8] .data.rel.ro.local is at file offset 0xa43c0
    # type[0] is at section_offset 0x5AC0, so file offset = 0xa43c0 + 0x5AC0 = 0xa9e80
    type0_file_off = 0xa43c0 + entries[0]
    f.seek(type0_file_off)
    type_bytes = f.read(64)
    print(f'\nType[0] at file offset 0x{type0_file_off:X}:')
    # Go _type structure: Size_(8), PtrBytes(8), ...
    # Actually let's look at the runtime._type layout
    hex_str = ' '.join(f'{b:02X}' for b in type_bytes)
    print(f'  Raw: {hex_str}')
    # First 8 bytes = Size_, next 8 = PtrBytes
    size_val = struct.unpack('<Q', type_bytes[0:8])[0]
    ptrbytes_val = struct.unpack('<Q', type_bytes[8:16])[0]
    print(f'  Size_ = {size_val} (0x{size_val:X})')
    print(f'  PtrBytes = {ptrbytes_val} (0x{ptrbytes_val:X})')
