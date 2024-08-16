use std::ffi::c_char;

extern "C" {
    fn sample_entrypoint(x: *const c_char);
}

fn main() {
    unsafe { sample_entrypoint(b"hello\0".as_ptr().cast()) }
}
