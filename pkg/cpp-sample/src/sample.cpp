#include <iostream>

extern "C" void sample_entrypoint(const char* name)
{
    std::cout << "hello world and also " << name << "\n";
}
