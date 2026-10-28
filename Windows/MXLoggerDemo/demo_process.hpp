#pragma once
#include "demo_model.hpp"
#include <chrono>
#include <cstdint>
#include <memory>

namespace demo {
class Child {
public:
    explicit Child(const std::string& configuration);
    ~Child();
    Child(const Child&) = delete;
    Child& operator=(const Child&) = delete;
    void send(const std::string& line);
    std::string receive(Progress& progress, std::chrono::seconds timeout);
    void finish(Progress& progress, std::chrono::seconds timeout);
private:
    struct State;
    std::unique_ptr<State> state_;
};
} // namespace demo
