# setup-ps3dk

A GitHub Action for building PS3 PRX modules on GitHub-hosted Ubuntu runners, using [FirebirdTA01/PS3DK](https://github.com/FirebirdTA01/PS3DK).

[The first SDK check](https://github.com/BenjiThatFoxGuy/setup-ps3dk/actions/runs/44928474115) passed on Ubuntu 26.04 x86_64. It produced a PRX and both SPRX containers; the downloaded files matched the build checksums.

## Usage

Until the first release, use `BenjiThatFoxGuy/setup-ps3dk@main`:

```yaml
jobs:
  build:
    runs-on: ubuntu-26.04
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
      - uses: BenjiThatFoxGuy/setup-ps3dk@main
      - run: make
```

The setup targets x86_64 and PS3DK v0.28.0. It exports `PS3DEV`, `PS3DK`, `PS3DK_SOURCE`, `PS3_TOOLS` and compiler/tool directories on `PATH` for later steps.

This setup includes SDK headers, PRX startup/linker files, `nidgen`, and ILP32 firmware import libraries: `lv2_stub`, `net_stub`, `c_stub`, `stdc_stub` and `fs_stub`. The socket archive exposes native `sys_net` imports for resident plugins, without process-runtime wrappers. Link with `-nostdlib` and the needed stub libraries, as shown in `scripts/smoke.sh`. VSH formatting and memory calls need `-lstdc_stub`; `c_stub` alone does not provide them. It does not install the process runtime, full SDK libraries, portlibs or SPU tools.

## CI

The expanded smoke check is awaiting CI verification. It covers socket calls, native thread creation and time, formatting and memory calls, filesystem imports and a custom `nidgen` import. It checks the linked PRX import tables and uploads `.prx`, `.sprx` and `.fake.sprx` outputs with logs and checksums. You can also start it manually from the Actions tab.

These checks do not run code on a PS3 or in RPCS3. A successful build is not a console compatibility test.

## Source and licenses

The action downloads the compiler, host tools and source archive from the [PS3DK v0.28.0 release](https://github.com/FirebirdTA01/PS3DK/releases/tag/v0.28.0). The install script checks each archive's SHA-256 before extraction. Cached installations use the release, host architecture, Ubuntu version and install recipe as their cache key.

PS3DK and its imported components keep their own licenses. The installation retains the source archive's `LICENSE` and `NOTICE`, along with the host-tools package's license files. See [NOTICE](NOTICE) for attribution. This action's own code is MIT licensed.
