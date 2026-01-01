#include <stdio.h>
#include <string>

int main(int argc, char** argv) {
    std::string name = "World";
    if (argc > 1) {
        name = argv[1];
    }
    printf("Hello %s!\n", name.c_str());
    return 0;
}