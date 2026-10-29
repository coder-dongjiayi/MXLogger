#include "demo_model.hpp"
#include <iostream>
#include <stdexcept>

int main(int argc, char** argv) {
    try {
        if (argc == 4 && std::string(argv[1]) == "--worker") return demo::run_worker(argv[2], argv[3]);
        if (argc == 4 && std::string(argv[1]) == "--self-test" && std::string(argv[2]) == "--report-dir") {
            const auto directory = std::filesystem::u8path(argv[3]);
            const int result = demo::smoke(directory);
            std::cout << (result == 0 ? "PASS" : "FAIL") << " Windows demo action model; reports: " << argv[3] << '\n';
            return result;
        }
        throw std::runtime_error("Usage: MXLoggerDemoModelCheck --self-test --report-dir <directory>");
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
