#ifndef MXLOGGER_TEST_PROCESS_HPP
#define MXLOGGER_TEST_PROCESS_HPP

#include "mxlogger_file.hpp"
#include <chrono>
#include <thread>
#include <vector>
#ifndef _WIN32
#include <mach-o/dyld.h>
#include <poll.h>
#include <spawn.h>
#include <sys/wait.h>
#include <signal.h>
extern char **environ;
#endif

namespace mxtest {
#ifdef _WIN32
using pipe_handle = HANDLE;
inline pipe_handle parse_pipe(const char *value) {
    return reinterpret_cast<HANDLE>(static_cast<uintptr_t>(std::stoull(value)));
}
inline bool read_byte(pipe_handle pipe, char &value) {
    DWORD count = 0;
    return ReadFile(pipe, &value, 1, &count, nullptr) && count == 1;
}
inline bool write_byte(pipe_handle pipe, char value) {
    DWORD count = 0;
    return WriteFile(pipe, &value, 1, &count, nullptr) && count == 1;
}
inline void wait_forever() { Sleep(INFINITE); }

inline std::wstring quote_argument(const std::wstring &value) {
    std::wstring result = L"\"";
    size_t slashes = 0;
    for (wchar_t ch : value) {
        if (ch == L'\\') { ++slashes; continue; }
        result.append(ch == L'"' ? slashes * 2 + 1 : slashes, L'\\');
        result += ch;
        slashes = 0;
    }
    result.append(slashes * 2, L'\\');
    result += L'"';
    return result;
}
#else
using pipe_handle = int;
inline pipe_handle parse_pipe(const char *value) { return std::stoi(value); }
inline bool read_byte(pipe_handle pipe, char &value) {
    ssize_t count;
    do { count = ::read(pipe, &value, 1); } while (count < 0 && errno == EINTR);
    return count == 1;
}
inline bool write_byte(pipe_handle pipe, char value) {
    ssize_t count;
    do { count = ::write(pipe, &value, 1); } while (count < 0 && errno == EINTR);
    return count == 1;
}
inline void wait_forever() { while (true) ::pause(); }
#endif

// Start independent executables, never fork a live logger. Two pipes provide
// barriers; bounded waits report worker failures instead of hanging the suite.
class worker {
public:
    worker(const std::string &dir, int id, int count = 150, bool crypt = false,
           const std::string &filename = "shared") {
#ifdef _WIN32
        SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
        HANDLE control[2]{}, report[2]{};
        if (!CreatePipe(&control[0], &control[1], &security, 0)) return;
        if (!CreatePipe(&report[0], &report[1], &security, 0)) {
            CloseHandle(control[0]); CloseHandle(control[1]); return;
        }
        bool ready = SetHandleInformation(control[1], HANDLE_FLAG_INHERIT, 0) &&
                     SetHandleInformation(report[0], HANDLE_FLAG_INHERIT, 0);
        std::wstring executable(32768, L'\0');
        DWORD length = GetModuleFileNameW(nullptr, &executable[0], static_cast<DWORD>(executable.size()));
        ready = ready && length > 0 && length < executable.size();
        executable.resize(length);
        std::vector<std::wstring> args = {executable, L"--ipc-worker",
            mxlogger::files::to_wide(dir.c_str()), mxlogger::files::to_wide(filename.c_str()),
            std::to_wstring(id), std::to_wstring(count), crypt ? L"1" : L"0",
            std::to_wstring(reinterpret_cast<uintptr_t>(control[0])),
            std::to_wstring(reinterpret_cast<uintptr_t>(report[1]))};
        std::wstring command;
        for (const auto &arg : args) command += (command.empty() ? L"" : L" ") + quote_argument(arg);
        STARTUPINFOW startup{};
        startup.cb = sizeof(startup);
        PROCESS_INFORMATION process{};
        ready = ready && CreateProcessW(executable.c_str(), &command[0], nullptr, nullptr,
                                         TRUE, 0, nullptr, nullptr, &startup, &process);
        CloseHandle(control[0]); CloseHandle(report[1]);
        if (!ready) { CloseHandle(control[1]); CloseHandle(report[0]); return; }
        CloseHandle(process.hThread);
        process_ = process.hProcess;
        control_ = control[1]; report_ = report[0];
#else
        int control[2], report[2];
        if (::pipe(control) != 0) return;
        if (::pipe(report) != 0) { ::close(control[0]); ::close(control[1]); return; }
        fcntl(control[1], F_SETFD, FD_CLOEXEC);
        fcntl(report[0], F_SETFD, FD_CLOEXEC);
        uint32_t size = 4096;
        char executable[4096];
        if (_NSGetExecutablePath(executable, &size) != 0) {
            for (int fd : {control[0], control[1], report[0], report[1]}) ::close(fd);
            return;
        }
        std::vector<std::string> args = {executable, "--ipc-worker", dir, filename,
            std::to_string(id), std::to_string(count), crypt ? "1" : "0",
            std::to_string(control[0]), std::to_string(report[1])};
        std::vector<char *> argv;
        for (auto &arg : args) argv.push_back(&arg[0]);
        argv.push_back(nullptr);
        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addclose(&actions, control[1]);
        posix_spawn_file_actions_addclose(&actions, report[0]);
        int result = posix_spawn(&pid_, executable, &actions, nullptr, argv.data(), environ);
        posix_spawn_file_actions_destroy(&actions);
        ::close(control[0]); ::close(report[1]);
        if (result != 0) { ::close(control[1]); ::close(report[0]); pid_ = -1; return; }
        control_ = control[1]; report_ = report[0];
#endif
    }
    ~worker() {
#ifdef _WIN32
        if (process_) {
            if (WaitForSingleObject(process_, 0) == WAIT_TIMEOUT) TerminateProcess(process_, 99);
            WaitForSingleObject(process_, 10000);
            CloseHandle(process_);
        }
        if (control_) CloseHandle(control_);
        if (report_) CloseHandle(report_);
#else
        if (pid_ > 0) { ::kill(pid_, SIGKILL); int status; ::waitpid(pid_, &status, 0); }
        if (control_ >= 0) ::close(control_);
        if (report_ >= 0) ::close(report_);
#endif
    }
    worker(const worker &) = delete;
    worker &operator=(const worker &) = delete;
    bool send(char command) { return valid_control() && write_byte(control_, command); }
    bool pending(int timeout = 10000) {
#ifdef _WIN32
        if (!report_) return false;
        auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout);
        do {
            DWORD count = 0;
            if (!PeekNamedPipe(report_, nullptr, 0, nullptr, &count, nullptr)) return false;
            if (count) return true;
            if (WaitForSingleObject(process_, 0) != WAIT_TIMEOUT) return false;
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        } while (std::chrono::steady_clock::now() < deadline);
        return false;
#else
        struct pollfd fd{report_, POLLIN, 0};
        return report_ >= 0 && ::poll(&fd, 1, timeout) > 0 && (fd.revents & POLLIN);
#endif
    }
    bool receive(char expected = 'D') {
        char response = 0;
        return pending() && read_byte(report_, response) && response == expected;
    }
    bool finish() { return send('Q') && receive('Q') && reap(false); }
    bool kill_and_wait() {
#ifdef _WIN32
        return process_ && TerminateProcess(process_, 99) && reap(true);
#else
        return pid_ > 0 && ::kill(pid_, SIGKILL) == 0 && reap(true);
#endif
    }
private:
    bool valid_control() const {
#ifdef _WIN32
        return control_ != nullptr;
#else
        return control_ >= 0;
#endif
    }
    bool reap(bool killed) {
#ifdef _WIN32
        if (WaitForSingleObject(process_, 10000) != WAIT_OBJECT_0) return false;
        DWORD status = 0;
        bool success = GetExitCodeProcess(process_, &status) && status == (killed ? 99 : 0);
        CloseHandle(process_);
        process_ = nullptr;
        return success;
#else
        int status = 0;
        pid_t result;
        do { result = ::waitpid(pid_, &status, 0); } while (result < 0 && errno == EINTR);
        if (result <= 0) return false;
        pid_ = -1;
        return killed ? WIFSIGNALED(status) && WTERMSIG(status) == SIGKILL
                      : WIFEXITED(status) && WEXITSTATUS(status) == 0;
#endif
    }
#ifdef _WIN32
    HANDLE process_ = nullptr, control_ = nullptr, report_ = nullptr;
#else
    pid_t pid_ = -1;
    int control_ = -1, report_ = -1;
#endif
};
} // namespace mxtest
#endif
