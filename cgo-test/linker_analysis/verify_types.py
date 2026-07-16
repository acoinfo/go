"""Verify embedded type pointers in final SylixOS Go binary.
Check whether ChanType.Elem pointers point to valid type structs.
"""
import struct, sys

binary = r'C:\Users\taoran\Desktop\cgo-test\main_nc_v5'

# From readelf -S:
# .data.rel.ro  VA=0xB7780  file_off=0xA7780  size=0x708E8
# runtime.types=0xB7780, runtime.etypes=0xCCDA0
TYPE_SECTION_VA = 0xB7780
TYPE_SECTION_FILE_OFF = 0xA7780
TYPE_START = 0xB7780    # runtime.types
TYPE_END   = 0xCCDA0    # runtime.etypes
SECTION_SIZE = 0x708E8

def va_to_file(va):
    return va - TYPE_SECTION_VA + TYPE_SECTION_FILE_OFF

def is_valid_type_addr(addr):
    """Check if addr looks like it could be a valid type pointer"""
    return TYPE_START <= addr < TYPE_END

def read_type_header(data, off):
    """Parse _type header from bytes at off. Returns dict or None."""
    if off + 24 > len(data):
        return None
    b = data[off:off+24]
    size_ = struct.unpack('<Q', b[0:8])[0]
    ptrbytes = struct.unpack('<Q', b[8:16])[0]
    hash_ = struct.unpack('<I', b[16:20])[0]
    tflag = b[20]
    align_ = b[21]
    fieldalign = b[22]
    kind = b[23]
    # Basic sanity: Size_ should be reasonable, Kind_ should be 0-31
    if size_ > 0x10000:
        return None
    if kind > 31:
        return None
    return {
        'off': off, 'Size_': size_, 'PtrBytes': ptrbytes,
        'Hash': hash_, 'TFlag': tflag, 'Align_': align_,
        'FieldAlign': fieldalign, 'Kind': kind
    }

KIND_NAMES = {
    0: 'Invalid', 1: 'Bool', 2: 'Int', 3: 'Int8', 4: 'Int16', 5: 'Int32',
    6: 'Int64', 7: 'Uint', 8: 'Uint8', 9: 'Uint16', 10: 'Uint32',
    11: 'Uint64', 12: 'Uintptr', 13: 'Float32', 14: 'Float64',
    15: 'Complex64', 16: 'Complex128', 17: 'Array', 18: 'Chan',
    19: 'Func', 20: 'Interface', 21: 'Map', 22: 'Pointer',
    23: 'Slice', 24: 'String', 25: 'Struct', 26: 'UnsafePointer',
    27: 'Uint8Alias', 28: 'ByteAlias', 29: 'IntAlias', 30: 'RuneAlias',
    31: 'Generic',
}

with open(binary, 'rb') as f:
    # Read the type section data
    f.seek(TYPE_SECTION_FILE_OFF)
    type_data = f.read(SECTION_SIZE)

print(f"Read {len(type_data)} bytes of type data")
print(f"Types VA range: 0x{TYPE_START:X} - 0x{TYPE_END:X}")
print()

# Scan for ChanType (Kind=18)
# _type header is 24 bytes. After that, ChanType has:
#   Elem  *Type   (8 bytes)
#   Dir   ChanDir (8 bytes)
# Total ChanType size from header: Size_ field

chan_count = 0
pointer_issues = 0

for off in range(0, min(len(type_data) - 80, TYPE_END - TYPE_START - 80), 8):
    t = read_type_header(type_data, off)
    if t is None:
        continue
    if t['Kind'] == 18:  # Chan
        chan_count += 1
        if chan_count > 10:
            break

        va = TYPE_START + off
        print(f"--- ChanType at VA 0x{va:X} (offset 0x{off:X}) ---")
        print(f"  Size_={t['Size_']} PtrBytes={t['PtrBytes']} Align_={t['Align_']}")

        # Elem is at offset 24 (right after _type header)
        if off + 32 <= len(type_data):
            elem_raw = struct.unpack('<Q', type_data[off+24:off+32])[0]
            dir_val = struct.unpack('<Q', type_data[off+32:off+40])[0]

            print(f"  Elem ptr = 0x{elem_raw:016X}")
            print(f"  Dir      = {dir_val}")

            if is_valid_type_addr(elem_raw):
                # Check if Elem points to something that looks like a type
                elem_off = elem_raw - TYPE_START
                if elem_off + 24 <= len(type_data):
                    et = read_type_header(type_data, elem_off)
                    if et:
                        kind_name = KIND_NAMES.get(et['Kind'], f'Unknown({et["Kind"]})')
                        print(f"  Elem -> Kind={et['Kind']} ({kind_name}) Size_={et['Size_']} [VALID TYPE]")
                    else:
                        print(f"  Elem -> INVALID TYPE HEADER at 0x{elem_raw:X}")
                        pointer_issues += 1
                else:
                    print(f"  Elem -> OUT OF RANGE (off 0x{elem_off:X})")
                    pointer_issues += 1
            else:
                if elem_raw == 0:
                    print(f"  Elem -> NULL")
                elif TYPE_START <= (elem_raw % 0x100000000) < TYPE_END:
                    print(f"  Elem -> 0x{elem_raw:X} (possibly with load bias?)")
                    print(f"    Try subtract load bias 0x40000000000: 0x{(elem_raw - 0x40000000000):X}")
                else:
                    print(f"  Elem -> OUTSIDE TYPE SECTION (0x{elem_raw:X} not in 0x{TYPE_START:X}-0x{TYPE_END:X})")
                    pointer_issues += 1
        print()

# Also check MapType (Kind=21)
print("=" * 60)
print("Checking MapType (Kind=21)...")
map_count = 0
for off in range(0, min(len(type_data) - 80, TYPE_END - TYPE_START - 80), 8):
    t = read_type_header(type_data, off)
    if t is None:
        continue
    if t['Kind'] == 21:  # Map
        map_count += 1
        if map_count > 5:
            break

        va = TYPE_START + off
        print(f"--- MapType at VA 0x{va:X} ---")
        print(f"  Size_={t['Size_']} PtrBytes={t['PtrBytes']}")

        # MapType has Key at +24, Value/Elem at +32, ... (after _type header)
        if off + 56 <= len(type_data):
            key_ptr = struct.unpack('<Q', type_data[off+24:off+32])[0]
            elem_ptr = struct.unpack('<Q', type_data[off+32:off+40])[0]

            print(f"  Key ptr  = 0x{key_ptr:016X}")
            print(f"  Elem ptr = 0x{elem_ptr:016X}")

            for name, ptr in [("Key", key_ptr), ("Elem", elem_ptr)]:
                if is_valid_type_addr(ptr):
                    pt = read_type_header(type_data, ptr - TYPE_START)
                    if pt:
                        kn = KIND_NAMES.get(pt['Kind'], f'Unknown({pt["Kind"]})')
                        print(f"  {name} -> Kind={pt['Kind']} ({kn}) [OK]")
                    else:
                        print(f"  {name} -> INVALID [ISSUE]")
                        pointer_issues += 1
                elif ptr == 0:
                    print(f"  {name} -> NULL")
                else:
                    print(f"  {name} -> OUTSIDE RANGE [ISSUE]")
                    pointer_issues += 1
        print()

print("=" * 60)
print(f"ChanTypes found: {chan_count}")
print(f"MapTypes found: {map_count}")
print(f"Pointer issues: {pointer_issues}")
if pointer_issues == 0:
    print("=> All embedded type pointers look VALID in the final binary")
else:
    print(f"=> Found {pointer_issues} potentially corrupt pointers!")
