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
