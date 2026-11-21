#!/usr/bin/env bash
set -euo pipefail
: "${SETUP_PS3DK_ROOT:?}" "${SETUP_PS3DK_ACTION:?}"
root="$SETUP_PS3DK_ROOT"
work="$(mktemp -d "$RUNNER_TEMP/ps3dk-download.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cd "$work"
while read -r digest asset; do
  curl --fail --location --retry 5 --proto '=https' --tlsv1.2     "https://github.com/FirebirdTA01/PS3DK/releases/download/v0.28.0/$asset" -o "$asset"
  printf '%s  %s\n' "$digest" "$asset" | sha256sum --check --strict
 done < "$SETUP_PS3DK_ACTION/sdk-assets.sha256"
mkdir -p "$root"
tar -xJf ps3dev-ppu.tar.xz -C "$root"
mkdir -p "$root/ps3dev/bin" "$root/source" "$root/licenses/host-tools"
tar -xJf ps3-sdk-src-v0.28.0.tar.xz -C "$root/source" --strip-components=1
mkdir tools
tar -xJf ps3-sdk-tools-v0.28.0-linux-x86_64.tar.xz -C tools --strip-components=1
cp -a tools/bin/. "$root/ps3dev/bin/"
# Retain the entire package's documentation and license files outside bin/.
cp -a tools/. "$root/licenses/host-tools/"
rm -rf "$root/licenses/host-tools/bin"
cp "$root/source/LICENSE" "$root/source/NOTICE" "$root/licenses/"
cp "$SETUP_PS3DK_ACTION/sdk-assets.sha256" "$root/licenses/"
export PS3DEV="$root/ps3dev"
export PS3DK="$PS3DEV/ps3dk"
export PATH="$PS3DEV/ppu/bin:$PS3DEV/bin:$PATH"
mkdir -p "$PS3DK/ppu/include" "$PS3DK/ppu/lib"
cp -a "$root/source/sdk/include/." "$PS3DK/ppu/include/"
cp "$root/source/runtime/lv2/crt/lv2-prx.ld" "$root/source/runtime/lv2/crt/lv2-prx.specs" "$PS3DK/ppu/lib/"
# The official Linux compiler archive does not include the installed PRX CRT.
# Assemble this small adjunct from the verified release source on the runner.
powerpc64-ps3-elf-gcc -mcpu=cell -c "$root/source/runtime/lv2/crt/lv2-prx.S"   -o "$PS3DK/ppu/lib/lv2-prx-crt.o"
# Generate native firmware import archives using the release's nidgen recipes.
# Keep sys_net's native socket symbols: the SDK's process-oriented front end
# renames them and needs librt/pthread initialization, unsuitable for VSH PRXs.
for library in lv2 net c; do
  nidgen archive --input "$root/source/tools/nidgen/nids/extracted/lib${library}_stub.yaml" \
    --toolchain-bin "$PS3DEV/ppu/bin" --out-dir "$work/stubs/$library" --abi ilp32
  install -m 0644 "$work/stubs/$library/lib${library}_stub.a" "$PS3DK/ppu/lib/"
done
nidgen archive --input "$root/source/tools/nidgen/nids/cellFs.yaml" \
  --toolchain-bin "$PS3DEV/ppu/bin" --out-dir "$work/stubs/fs" --abi ilp32
install -m 0644 "$work/stubs/fs/libfs_stub.a" "$PS3DK/ppu/lib/"
ln -sf libfs_stub.a "$PS3DK/ppu/lib/libsysfs.a"
# Include the SDK's native libc extras, matching its stub install recipe.
make -C "$root/source/sdk/libc_stub_extras" all PSL1GHT="$PS3DK"
powerpc64-ps3-elf-ar r "$PS3DK/ppu/lib/libc_stub.a" "$root/source/sdk/libc_stub_extras/build/"*.o
powerpc64-ps3-elf-ranlib "$PS3DK/ppu/lib/libc_stub.a"
printf '%s\n' 'FirebirdTA01/PS3DK v0.28.0' \
  'Source commit: 0bd322f172e59a25aeb0a4b72c23539f8bd574aa' \
  'ILP32 native firmware imports: sysPrxForUser, sys_net, sys_libc, sys_fs' > "$root/PROVENANCE.txt"
