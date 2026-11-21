#!/usr/bin/env bash
set -euo pipefail
: "${PS3DEV:?}" "${PS3DK:?}"
mkdir -p smoke-artifact
exec > >(tee smoke-artifact/build.log) 2>&1
cp smoke/main.c smoke-artifact/
cp smoke/minimal.specs smoke-artifact/
cp sdk-assets.sha256 smoke-artifact/
cp "$PS3DEV/../PROVENANCE.txt" smoke-artifact/
powerpc64-ps3-elf-gcc --version
prx-gen --version
powerpc64-ps3-elf-gcc -mcpu=cell -std=gnu99 -Wall -Wextra -Werror   -I"$PS3DK/ppu/include" -c smoke/main.c -o smoke-artifact/smoke.o
powerpc64-ps3-elf-gcc -mcpu=cell -specs="$PS3DK/ppu/lib/lv2-prx.specs"   -specs=smoke/minimal.specs -nostartfiles -Wl,-q -Wl,--no-warn-rwx-segments   -Wl,-T,"$PS3DK/ppu/lib/lv2-prx.ld" "$PS3DK/ppu/lib/lv2-prx-crt.o"   smoke-artifact/smoke.o -o smoke-artifact/smoke.elf
prx-gen build smoke-artifact/smoke.elf -o smoke-artifact/smoke.prx --name sdk_smoke
prx-gen check smoke-artifact/smoke.prx | tee smoke-artifact/prx-check.txt
make_sprx smoke-artifact/smoke.prx smoke-artifact/smoke.sprx
fself smoke-artifact/smoke.prx smoke-artifact/smoke.fake.sprx
powerpc64-ps3-elf-readelf -h -l smoke-artifact/smoke.prx > smoke-artifact/readelf.txt
python3 - <<'PY'
from pathlib import Path
import struct
p = Path('smoke-artifact')
prx = (p / 'smoke.prx').read_bytes()
assert prx[:4] == b'\x7fELF'
assert prx[4:6] == bytes([2, 2]), 'Expected ELF64 big-endian'
assert prx[7] == 0x66 and struct.unpack_from('>H', prx, 16)[0] == 0xffa4
for name in ('smoke.sprx', 'smoke.fake.sprx'):
    data = (p / name).read_bytes()
    assert data[:4] == b'SCE\x00', name
    assert len(data) > 128, name
    print(f'{name}: SCE container, {len(data)} bytes')
print('PRX identity and both SELF container headers verified')
PY
(cd smoke-artifact && sha256sum smoke.o smoke.elf smoke.prx smoke.sprx smoke.fake.sprx > SHA256SUMS)
