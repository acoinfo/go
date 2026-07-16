import subprocess, re

result = subprocess.run([
    r'D:\RealEvo\compiler\aarch64-sylixos-toolchain\bin\aarch64-sylixos-elf-readelf.exe',
    '-r', r'C:\Users\taoran\Desktop\cgo-test\main_nc_v5'
], capture_output=True, text=True)

lines = result.stdout.split('\n')
offsets = []
for line in lines:
    if 'R_AARCH64_RELATIV' in line:
        parts = line.strip().split()
        if parts:
            off = int(parts[0], 16)
            offsets.append(off)

offsets.sort()
print(f'Total RELATIVE relocations: {len(offsets)}')
print(f'Range: 0x{min(offsets):X} - 0x{max(offsets):X}')

# Check gaps
gaps = []
prev = offsets[0]
for o in offsets[1:]:
    gap = o - prev
    if gap > 0x1000:
        gaps.append((prev, o, gap))
    prev = o

print(f'Large gaps (>0x1000): {len(gaps)}')
for prev_o, next_o, gap in gaps[:10]:
    print(f'  0x{prev_o:X} -> 0x{next_o:X} (gap=0x{gap:X})')

# Check type area: VA 0xe7780 - 0xfcda0
type_start = 0xe7780
type_end = 0xfcda0
in_type_area = [o for o in offsets if type_start <= o <= type_end]
print(f'\nRelocations in type area (0x{type_start:X}-0x{type_end:X}): {len(in_type_area)}')
if in_type_area:
    for o in in_type_area[:10]:
        print(f'  0x{o:X}')
else:
    print('  NONE - types are not being relocated!')

# Find the biggest gap to see where types are relative to relocated data
biggest = max(gaps, key=lambda x: x[2])
print(f'\nBiggest gap: 0x{biggest[0]:X} -> 0x{biggest[1]:X} (0x{biggest[2]:X} bytes)')
print(f'Type area: 0x{type_start:X} -> 0x{type_end:X}')
print(f'Is type area in the gap? {biggest[0] <= type_start and type_end <= biggest[1]}')
