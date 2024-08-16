Sample Rust crate consuming the cpp-sample package.

To run, in the root of the repo:

```bash
docker build -t build .
docker run build pkg/cpp-sample
cd sample
cargo run --target x86_64-unknown-linux-musl
```
