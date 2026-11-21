#!/usr/bin/env bash
set -euo pipefail
: "${PS3DEV:?}" "${PS3DK:?}" "${PS3DK_SOURCE:?}"
mkdir -p smoke-artifact
exec > >(tee smoke-artifact/build.log) 2>&1
cp smoke/main.c smoke/vshmain.yaml smoke-artifact/
cp sdk-assets.sha256 smoke-artifact/
cp "$PS3DEV/../PROVENANCE.txt" smoke-artifact/
powerpc64-ps3-elf-gcc --version
prx-gen --version
nidgen --version
nidgen archive --input smoke/vshmain.yaml --toolchain-bin "$PS3DEV/ppu/bin" \
  --out-dir smoke-artifact/imports --abi ilp32
powerpc64-ps3-elf-gcc -mcpu=cell -std=gnu99 -Os -Wall -Wextra -Werror \
  -fno-builtin -I"$PS3DK/ppu/include" -c smoke/main.c -o smoke-artifact/smoke.o
powerpc64-ps3-elf-gcc -mcpu=cell -specs="$PS3DK/ppu/lib/lv2-prx.specs" \
  -nostdlib -Wl,-q -Wl,--no-warn-rwx-segments \
  -Wl,-T,"$PS3DK/ppu/lib/lv2-prx.ld" -Wl,-Map,smoke-artifact/smoke.map \
  "$PS3DK/ppu/lib/lv2-prx-crt.o" smoke-artifact/smoke.o \
  -L"$PS3DK/ppu/lib" -Wl,--start-group smoke-artifact/imports/libvshmain_stub.a \
  -llv2_stub -lnet_stub -lc_stub -lfs_stub -lgcc -Wl,--end-group \
  -o smoke-artifact/smoke.elf
powerpc64-ps3-elf-nm --undefined-only smoke-artifact/smoke.elf > smoke-artifact/undefined.txt
if [[ -s smoke-artifact/undefined.txt ]]; then
  echo '::error::Linked smoke ELF has unresolved symbols'
  exit 1
fi
prx-gen build smoke-artifact/smoke.elf -o smoke-artifact/smoke.prx --name sdk_smoke
prx-gen check smoke-artifact/smoke.prx | tee smoke-artifact/prx-check.txt
make_sprx smoke-artifact/smoke.prx smoke-artifact/smoke.sprx
fself smoke-artifact/smoke.prx smoke-artifact/smoke.fake.sprx
powerpc64-ps3-elf-readelf -h -l smoke-artifact/smoke.prx > smoke-artifact/readelf.txt
python3 scripts/check-imports.py | tee smoke-artifact/import-check.txt
(cd smoke-artifact && sha256sum smoke.o smoke.elf smoke.prx smoke.sprx smoke.fake.sprx > SHA256SUMS)
