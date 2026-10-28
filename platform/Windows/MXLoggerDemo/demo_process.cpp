#include "demo_process.hpp"
#include <algorithm>
#include <cerrno>
#include <sstream>
#include <stdexcept>
#include <thread>
#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
extern char** environ;
#endif

namespace demo {
namespace {
#ifdef _WIN32
using Pipe = HANDLE;
constexpr Pipe invalid_pipe = nullptr;
void close_pipe(Pipe& pipe) { if (pipe) CloseHandle(pipe); pipe = nullptr; }
std::string pipe_text(Pipe pipe) { return std::to_string(reinterpret_cast<uintptr_t>(pipe)); }
Pipe parse_pipe(const std::string& text) { return reinterpret_cast<Pipe>(static_cast<uintptr_t>(std::stoull(text))); }
bool write_bytes(Pipe pipe, const char* data, size_t length) {
    while (length) {
        DWORD written = 0;
        if (!WriteFile(pipe, data, static_cast<DWORD>(length), &written, nullptr) || !written) return false;
        data += written; length -= written;
    }
    return true;
}
bool read_byte(Pipe pipe, char& byte) { DWORD count = 0; return ReadFile(pipe, &byte, 1, &count, nullptr) && count == 1; }
bool available(Pipe pipe) {
    DWORD count = 0;
    if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &count, nullptr)) throw std::runtime_error("Worker pipe closed unexpectedly");
    return count != 0;
}
#else
using Pipe = int;
constexpr Pipe invalid_pipe = -1;
void close_pipe(Pipe& pipe) { if (pipe >= 0) ::close(pipe); pipe = -1; }
std::string pipe_text(Pipe pipe) { return std::to_string(pipe); }
Pipe parse_pipe(const std::string& text) { return std::stoi(text); }
bool write_bytes(Pipe pipe, const char* data, size_t length) {
    fcntl(pipe, F_SETNOSIGPIPE, 1);
    while (length) {
        const auto written = ::write(pipe, data, length);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return false;
        data += written; length -= static_cast<size_t>(written);
    }
    return true;
}
bool read_byte(Pipe pipe, char& byte) {
    ssize_t count;
    do { count = ::read(pipe, &byte, 1); } while (count < 0 && errno == EINTR);
    return count == 1;
}
bool available(Pipe pipe) {
    pollfd descriptor{pipe, POLLIN, 0};
    if (poll(&descriptor, 1, 0) < 0 && errno != EINTR) throw std::runtime_error("Worker pipe poll failed");
    return (descriptor.revents & (POLLIN | POLLHUP | POLLERR)) != 0;
}
#endif
void send_line(Pipe pipe, const std::string& value) {
    if (value.size() > 65536 || !write_bytes(pipe, value.data(), value.size()) || !write_bytes(pipe, "\n", 1))
        throw std::runtime_error("Worker pipe write failed");
}
std::string blocking_line(Pipe pipe) {
    std::string value;
    char byte = 0;
    while (value.size() <= 65536 && read_byte(pipe, byte)) {
        if (byte == '\n') return value;
        value += byte;
    }
    throw std::runtime_error("Invalid worker pipe message");
}
}
struct Child::State {
    Pipe input = invalid_pipe, output = invalid_pipe;
    Pipe child_input = invalid_pipe, child_output = invalid_pipe;
#ifdef _WIN32
    HANDLE process = nullptr;
    ~State() {
        close_pipe(input); close_pipe(output); close_pipe(child_input); close_pipe(child_output);
        if (process) {
            if (WaitForSingleObject(process, 0) == WAIT_TIMEOUT) {
                TerminateProcess(process, 90); WaitForSingleObject(process, 5000);
            }
            CloseHandle(process);
        }
    }
    bool done(int& code) {
        if (WaitForSingleObject(process, 0) != WAIT_OBJECT_0) return false;
        DWORD exit_code = 0;
        if (!GetExitCodeProcess(process, &exit_code)) throw std::runtime_error("GetExitCodeProcess failed");
        code = static_cast<int>(exit_code); return true;
    }
#else
    pid_t process = -1;
    bool reaped = false;
    int exit_code = 0;
    ~State() {
        close_pipe(input); close_pipe(output); close_pipe(child_input); close_pipe(child_output);
        if (process > 0 && !reaped) { kill(process, SIGKILL); while (waitpid(process, nullptr, 0) < 0 && errno == EINTR) {} }
    }
    bool done(int& code) {
        if (!reaped) {
            int status = 0;
            auto result = waitpid(process, &status, WNOHANG);
            if (result == 0 || (result < 0 && errno == EINTR)) return false;
            if (result < 0) throw std::runtime_error("waitpid failed");
            reaped = true; exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 90;
        }
        code = exit_code; return true;
    }
#endif
};
Child::Child(const std::string& configuration) : state_(new State) {
    auto& s = *state_;
#ifdef _WIN32
    SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
    if (!CreatePipe(&s.child_input, &s.input, &security, 0) || !CreatePipe(&s.output, &s.child_output, &security, 0) ||
        !SetHandleInformation(s.input, HANDLE_FLAG_INHERIT, 0) || !SetHandleInformation(s.output, HANDLE_FLAG_INHERIT, 0))
        throw std::runtime_error("CreatePipe failed: " + std::to_string(GetLastError()));
    std::vector<wchar_t> executable(32768);
    DWORD size = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
    if (!size || size == executable.size()) throw std::runtime_error("Cannot locate demo executable");
    std::wstring command = L"\"" + std::wstring(executable.data(), size) + L"\" --worker ";
    for (auto pipe : {s.child_input, s.child_output}) {
        auto number = pipe_text(pipe); command.append(number.begin(), number.end()); command += L' ';
    }
    SIZE_T bytes = 0;
    InitializeProcThreadAttributeList(nullptr, 1, 0, &bytes);
    std::vector<unsigned char> storage(bytes);
    auto* attributes = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(storage.data());
    if (!InitializeProcThreadAttributeList(attributes, 1, 0, &bytes)) throw std::runtime_error("Process attributes failed");
    HANDLE inherited[] = {s.child_input, s.child_output};
    STARTUPINFOEXW startup{};
    startup.StartupInfo.cb = sizeof(startup); startup.lpAttributeList = attributes;
    PROCESS_INFORMATION info{};
    BOOL success = UpdateProcThreadAttribute(attributes, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherited, sizeof(inherited), nullptr, nullptr)
        && CreateProcessW(executable.data(), command.data(), nullptr, nullptr, TRUE,
                          EXTENDED_STARTUPINFO_PRESENT | CREATE_NO_WINDOW, nullptr, nullptr, &startup.StartupInfo, &info);
    const auto error = GetLastError();
    DeleteProcThreadAttributeList(attributes);
    if (!success) throw std::runtime_error("CreateProcessW failed: " + std::to_string(error));
    s.process = info.hProcess; CloseHandle(info.hThread);
#else
    int to_child[2], to_parent[2];
    if (pipe(to_child) != 0) throw std::runtime_error("pipe failed");
    s.child_input = to_child[0]; s.input = to_child[1];
    if (pipe(to_parent) != 0) throw std::runtime_error("pipe failed");
    s.output = to_parent[0]; s.child_output = to_parent[1];
    const int target_input = std::max({s.input, s.output, s.child_input, s.child_output}) + 10;
    const int target_output = target_input + 1;
    uint32_t length = 0;
    _NSGetExecutablePath(nullptr, &length);
    std::vector<char> executable(length);
    if (_NSGetExecutablePath(executable.data(), &length) != 0) throw std::runtime_error("Cannot locate demo executable");
    std::string read = pipe_text(target_input), write = pipe_text(target_output);
    char worker[] = "--worker";
    char* arguments[] = {executable.data(), worker, read.data(), write.data(), nullptr};
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    if (posix_spawn_file_actions_init(&actions) != 0) throw std::runtime_error("spawn actions failed");
    if (posix_spawnattr_init(&attributes) != 0) { posix_spawn_file_actions_destroy(&actions); throw std::runtime_error("spawn attributes failed"); }
    int result = posix_spawn_file_actions_adddup2(&actions, s.child_input, target_input);
    if (!result) result = posix_spawn_file_actions_adddup2(&actions, s.child_output, target_output);
    if (!result) result = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT);
    if (!result) result = posix_spawn(&s.process, executable.data(), &actions, &attributes, arguments, environ);
    posix_spawnattr_destroy(&attributes); posix_spawn_file_actions_destroy(&actions);
    if (result) throw std::runtime_error("posix_spawn failed: " + std::to_string(result));
#endif
    close_pipe(s.child_input); close_pipe(s.child_output);
    send(configuration); // Config/key travels over a private pipe, never the command line.
}
Child::~Child() = default;
void Child::send(const std::string& line) { send_line(state_->input, line); }
std::string Child::receive(Progress& progress, std::chrono::seconds timeout) {
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    std::string result;
    while (std::chrono::steady_clock::now() < deadline && !progress.cancel) {
        if (available(state_->output)) {
            char byte = 0;
            if (!read_byte(state_->output, byte)) throw std::runtime_error("Worker exited before its reply");
            if (byte == '\n') return result;
            result += byte;
            if (result.size() > 65536) throw std::runtime_error("Worker reply too large");
        } else {
            int code = 0;
            if (state_->done(code)) throw std::runtime_error("Worker exited early: " + std::to_string(code));
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    }
    throw std::runtime_error(progress.cancel ? "Cancelled / 已取消" : "Worker timed out / 子进程超时");
}
void Child::finish(Progress& progress, std::chrono::seconds timeout) {
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (!progress.cancel && std::chrono::steady_clock::now() < deadline) {
        int code = 0;
        if (state_->done(code)) {
            if (code != 0) throw std::runtime_error("Worker exit code: " + std::to_string(code));
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    throw std::runtime_error(progress.cancel ? "Cancelled / 已取消" : "Worker exit timeout");
}
int run_worker(const std::string& input, const std::string& output) {
    Pipe read = invalid_pipe, write = invalid_pipe;
    int code = 0;
    try {
        read = parse_pipe(input); write = parse_pipe(output);
        {
            Session session(decode_config(blocking_line(read)), false);
            send_line(write, "READY");
            const auto command = blocking_line(read);
            std::istringstream stream(command);
            std::string run; int count = 0;
            if (!(stream >> run >> count) || count <= 0 || count > 100000) throw std::runtime_error("Invalid worker request");
            session.sequence(run, 1, count);
            session.logger()->flush();
        }
        send_line(write, "OK"); // Only after releasing the session and live-file lease.
    } catch (...) {
        try { if (write != invalid_pipe) send_line(write, "ERROR"); } catch (...) {}
        code = 1;
    }
    close_pipe(read); close_pipe(write);
    return code;
}
} // namespace demo
