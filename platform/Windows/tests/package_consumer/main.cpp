// This program must compile using only installed public headers and libraries.
#include <mxlogger.hpp>
#include <mxlogger_util.hpp>
#include <chrono>
#include <filesystem>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

int main(int argc, char** argv) {
    try {
        if (argc != 2) throw std::runtime_error("Usage: consumer <fresh-log-directory>");
        const std::string version = mx_logger::version();
        if (version != "2.3.0") throw std::runtime_error("Unexpected linked Core version: " + version);
        const auto root = std::filesystem::absolute(std::filesystem::u8path(argv[1])) /
            ("run-" + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
        std::filesystem::create_directories(root);
        const auto directory = root.u8string();
        auto* logger = mx_logger::initialize_namespace("package-consumer", directory.c_str(),
            "yyyy_MM_dd", "sdk", nullptr, "0123456789abcdef", "abcdef0123456789");
        if (!logger) throw std::runtime_error("Logger initialization failed");
        const std::string path = logger->diskcache_path();
        if (logger->log(1, "SDK", "installed package write/read", "package", true) != 0)
            throw std::runtime_error(logger->error_desc());
        logger->flush();
        mx_logger::destroy();
        size_t count = 0;
        for (const auto& file : std::filesystem::directory_iterator(std::filesystem::u8path(path))) {
            if (file.path().extension() != ".mx") continue;
            std::vector<std::map<std::string, std::string>> records;
            const auto filename = file.path().u8string();
            mxlogger::util::mxlogger_util::select_log_form_path(filename.c_str(), &records,
                "0123456789abcdef", "abcdef0123456789");
            for (const auto& record : records)
                if (record.at("msg") == "installed package write/read") ++count;
        }
        if (count != 1) throw std::runtime_error("Encrypted record readback failed");
        std::cout << "MXLOGGER_PACKAGE_OK " << version << '\n';
        return 0;
    } catch (const std::exception& error) {
        mx_logger::destroy();
        std::cerr << error.what() << '\n';
        return 1;
    }
}
