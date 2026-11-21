# setup-ps3dk

A GitHub Action for building PS3 PRX modules on GitHub-hosted Ubuntu runners, using [FirebirdTA01/PS3DK](https://github.com/FirebirdTA01/PS3DK).

The action is under development. CI has not verified the setup yet.

## Usage

Until the first release, use `BenjiThatFoxGuy/setup-ps3dk@main`:

```yaml
jobs:
  build:
    runs-on: ubuntu-26.04
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: BenjiThatFoxGuy/setup-ps3dk@main
      - run: make
```

The setup targets x86_64 and PS3DK v0.28.0. It exports `PS3DEV`, `PS3DK` and compiler/tool directories on `PATH` for later steps.

This is a minimal PPU/PRX setup: the PPU compiler, SDK headers, PRX startup object, linker files and host tools. It does not install the full SDK libraries, PSL1GHT, portlibs or the SPU toolchain. Code that needs those libraries will need more setup. For a library-free module, see the smoke build in `scripts/smoke.sh`.

## CI

The SDK check workflow is intended to compile and link a small module, build and check its PRX, then produce `.sprx` and `.fake.sprx` containers. It uploads the outputs with logs and checksums. You can also start it manually from the Actions tab.

These checks do not run code on a PS3 or in RPCS3. A successful build is not a console compatibility test.

## Source and licenses

The action downloads the compiler, host tools and source archive from the [PS3DK v0.28.0 release](https://github.com/FirebirdTA01/PS3DK/releases/tag/v0.28.0). The install script checks each archive's SHA-256 before extraction. Cached installations use the release, host architecture, Ubuntu version and install recipe as their cache key.

PS3DK and its imported components keep their own licenses. The installation retains the source archive's `LICENSE` and `NOTICE`, along with the host-tools package's license files. See [NOTICE](NOTICE) for attribution. This action's own code is MIT licensed.
