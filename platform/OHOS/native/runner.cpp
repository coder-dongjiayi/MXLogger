#include "smoke.hpp"
#include <exception>
#include <iostream>
#include <string>

int main(int argc, char **argv) {
    if (argc != 3 || (std::string(argv[2]) != "plain" && std::string(argv[2]) != "encrypted")) {
        std::cerr << "usage: mxlogger_poc_runner ABSOLUTE_DIRECTORY plain|encrypted\n";
        return 2;
    }
    try {
        std::cout << "MXLOGGER_OHOS_POC " << mxlogger_poc::run(argv[1], std::string(argv[2]) == "encrypted") << '\n';
        return 0;
    } catch (const std::exception &error) {
        std::cerr << "MXLOGGER_OHOS_POC_FAILED " << error.what() << '\n';
        return 1;
    }
}
