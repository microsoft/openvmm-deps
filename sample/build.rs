fn main() {
    println!("cargo:rustc-link-search=../sysroot/usr/lib");
    println!("cargo:rustc-link-lib=static=sample");
    println!("cargo:rustc-link-lib=static=stdc++");
}
