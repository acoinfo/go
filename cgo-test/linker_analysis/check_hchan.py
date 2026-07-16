import struct

go_o = r'C:\Users\taoran\Desktop\cgo-test\linker_analysis\captured_link\go.o'

with open(go_o, 'rb') as f:
    f.seek(0x8e8e0)
    sec4 = f.read(0x15620)

# Search for Chan type: Kind=18, Size_=96
for off in range(0, min(0x50000, len(sec4) - 80), 4):
    if off + 64 > len(sec4):
        break
    b = sec4[off:off+48]
    size_ = struct.unpack('<Q', b[0:8])[0]
    ptrbytes = struct.unpack('<Q', b[8:16])[0]
    kind = b[23]

    if size_ == 96 and kind == 18:  # Chan, Size=96
        extra = sec4[off+48:off+64]
        elem_ptr = struct.unpack('<Q', extra[0:8])[0]
        dir_val = struct.unpack('<Q', extra[8:16])[0]
        print(f'hchan at sec[4] offset 0x{off:X}')
        print(f'  Size_={size_} PtrBytes={ptrbytes} Kind={kind}')
        print(f'  Elem ptr=0x{elem_ptr:X} Dir={dir_val}')
        break
else:
    # Try different kind/size combinations
    print('hchan (Size=96, Kind=18) not found')
    # Search for any Chan type
    for off in range(0, min(0x50000, len(sec4) - 80), 4):
        b = sec4[off:off+48]
        kind = b[23]
        if kind == 18:  # Any Chan
            size_ = struct.unpack('<Q', b[0:8])[0]
            print(f'Chan at 0x{off:X}: Size_={size_}')
            if len([1 for o2 in range(off, min(off+100, len(sec4)), 4) if o2+48 <= len(sec4) and struct.unpack('<Q', sec4[o2:o2+8])[0] < 0x1000]) < 3:
                continue
