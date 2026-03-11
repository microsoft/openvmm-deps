This repo contains a small build system for openvmm dependencies.

To use, first clone this repo and then init submodules:
```bash
git submodule init
git submodule update
```

Then build the Dockerfile to produce the results for the desired architecture:

```bash
docker build --platform x86_64 --output type=local,dest=out .
docker build --platform aarch64 --output type=local,dest=out .
```

The resulting file system will be in `out/{sdk,dbgrd,shell}/sysroot.*.gz`.

For local testing, you can:
- Copy the `out/sdk/sysroot.tar.gz` to `<openvmm src>/.packages/openvmm-deps/`
- untar the file to overwrite the libs
- rebuild openvmm

## Updating Kernel Configs

Kernel configs live in `pkg/linux/{x86_64,aarch64}.config`. To update them:

1. Edit the config file to add or change options.
2. Build the kernel for the target architecture:
   ```bash
   docker build --platform linux/amd64 --target result-linux --output type=local,dest=out/linux -f Dockerfile .
   ```
   The build runs `make olddefconfig` inside the container, which resolves
   dependencies and sets defaults for any new options.
3. Copy the final config back from the build output:
   ```bash
   cp out/linux/config pkg/linux/x86_64.config
   ```
4. Commit the updated config. The committed config should always reflect the
   exact output of `olddefconfig` so that rebuilds are reproducible.

For aarch64, use `--platform linux/arm64` and copy to `pkg/linux/aarch64.config`.
