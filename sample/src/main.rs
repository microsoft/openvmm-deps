use std::ffi::c_char;

extern "C" {
    fn sample_entrypoint(x: *const c_char);
}

fn main() {
    unsafe { sample_entrypoint(c"hello".as_ptr().cast()) }
}
