#!/usr/bin/env python3
"""Check actual PRX import tables against upstream NID definitions on CI."""
import json
import os
import re
import struct
from pathlib import Path

p = Path('smoke-artifact')
data = (p / 'smoke.prx').read_bytes()
assert data[:8] == b'\x7fELF\x02\x02\x01\x66'
assert struct.unpack_from('>H', data, 16)[0] == 0xffa4
phoff = struct.unpack_from('>Q', data, 32)[0]
stride, count = struct.unpack_from('>HH', data, 54)
loads = []
for i in range(count):
    off = phoff + stride * i
    kind, flags, pos, va, pa, size, memsize, align = struct.unpack_from('>IIQQQQQQ', data, off)
    if kind == 1:
        loads.append((pos, va, pa, size))

def offset(va):
    for pos, base, pa, size in loads:
        if base <= va < base + size:
            return pos + va - base
    raise AssertionError(f'address outside load segments: {va:x}')

def u32(pos):
    return struct.unpack_from('>I', data, pos)[0]

# prx-gen writes the module-info file offset to the first LOAD's p_paddr.
mi = loads[0][2]
start, end = struct.unpack_from('>II', data, mi + 0x2c)
imports = {}
while start < end:
    pos = offset(start)
    size = data[pos] or 44
    assert size >= 28 and start + size <= end
    functions = struct.unpack_from('>H', data, pos + 6)[0]
    namepos = offset(u32(pos + 0x10))
    name = data[namepos:data.index(0, namepos)].decode('ascii')
    nidpos = offset(u32(pos + 0x14))
    imports.setdefault(name, set()).update(struct.unpack_from(f'>{functions}I', data, nidpos))
    start += size
assert start == end

source = Path(os.environ['PS3DK_SOURCE']) / 'tools/nidgen/nids'
required = {
    'sysPrxForUser': ('extracted/liblv2_stub.yaml', ['sys_ppu_thread_create', 'sys_time_get_system_time']),
    'sys_net': ('extracted/libnet_stub.yaml', ['socket', 'bind', 'send', 'socketclose', 'socketpoll']),
    'stdc': ('../../../plugin-imports/stdc.yaml', ['snprintf', 'vsnprintf', 'memcpy', 'memset', 'memchr', 'memcmp', 'strlen', 'strchr', 'strcmp', 'strncmp', 'strstr']),
    'sys_fs': ('cellFs.yaml', ['cellFsOpen', 'cellFsRead', 'cellFsClose']),
    'vshmain': (None, ['vshmain_EB757101']),
}
report = {}
for library, (yaml, symbols) in required.items():
    text = (source / yaml).read_text() if yaml else Path('smoke/vshmain.yaml').read_text()
    report[library] = {}
    for symbol in symbols:
        match = re.search(r'- name: ' + re.escape(symbol) + r'\s+nid: [\'\"]?(0x[0-9a-fA-F]+)', text)
        assert match, f'{symbol}: source NID not found'
        nid = int(match[1], 16)
        assert nid in imports.get(library, set()), f'{library}:{symbol} missing from PRX import table'
        report[library][symbol] = f'0x{nid:08x}'
(p / 'imports.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
for name in ('smoke.sprx', 'smoke.fake.sprx'):
    container = (p / name).read_bytes()
    assert container[:4] == b'SCE\x00' and len(container) > 128
    print(f'{name}: SCE container, {len(container)} bytes')
print('Required firmware imports and both container headers verified')
