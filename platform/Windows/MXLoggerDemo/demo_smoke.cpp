#include "demo_model.hpp"
#include "mxlogger_util.hpp"
#include "json/cJSON.h"
#include <chrono>
#include <fstream>
#include <functional>
#include <iterator>
#include <memory>
#include <sstream>
#include <stdexcept>

namespace demo {
namespace fs = std::filesystem;
namespace {
void expect(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}
size_t count_tag(const Records& records, const std::string& tag) {
    size_t count = 0;
    for (const auto& record : records) if (field(record, "tag") == tag) ++count;
    return count;
}
}
int smoke(const fs::path& report_dir) {
    fs::create_directories(report_dir);
    const auto data = report_dir / fs::u8path("数据 with spaces-" + unique_id());
    std::ostringstream log;
    std::unique_ptr<cJSON, decltype(&cJSON_Delete)> report(cJSON_CreateObject(), cJSON_Delete);
    auto* cases = cJSON_AddArrayToObject(report.get(), "cases");
    bool passed = true;
    auto test = [&](const char* name, const std::function<void()>& body) {
        auto* item = cJSON_CreateObject();
        cJSON_AddStringToObject(item, "name", name);
        try { body(); cJSON_AddBoolToObject(item, "passed", true); log << "PASS " << name << '\n'; }
        catch (const std::exception& error) {
            passed = false; cJSON_AddBoolToObject(item, "passed", false);
            cJSON_AddStringToObject(item, "error", error.what());
            log << "FAIL " << name << ": " << error.what() << '\n';
        }
        cJSON_AddItemToArray(cases, item);
    };
    for (bool encrypted : {false, true}) {
        const std::string label = encrypted ? "AES-CFB-128" : "plaintext";
        test(label.c_str(), [&] {
            Config config; config.root = data.u8string(); config.encrypted = encrypted;
            config.name_space = encrypted ? "encrypted.中文" : "plain.中文";
            Session session(config);
            const auto token = session.token();
            expect(mx_logger::global_for_loggerToken(token.c_str()) == session.logger(), "Token lookup");
            for (int level = 0; level < 5; ++level) session.sample(level);
            session.sample(1, true); session.sample(1, false, true);
            const auto marker = "secret-你好-" + unique_id();
            session.write(1, marker, "roundtrip");
            session.logger()->flush();
            auto records = session.all_records();
            expect(records.size() == 9 && count_tag(records, "roundtrip") == 1, "Header + 8 records");
            expect(field(records.front(), "name") == "com.djy.mxlogger.fileHeader", "Header first");
            expect(field(records.back(), "msg") == marker, "Unicode roundtrip");
            session.settings(false, false, 0, config.max_age, config.max_size);
            session.sample(4);
            expect(session.all_records().size() == records.size(), "Disabled write must not append");
            session.settings(true, false, 3, config.max_age, config.max_size);
            session.sample(2); session.sample(3);
            expect(session.all_records().size() == records.size() + 1, "Minimum level filter");
            session.rebuild();
            expect(session.token() == token && session.logger()->log_level() == 3, "Rebuild settings/token");
            expect(session.all_records().size() == records.size() + 1, "Rebuild persistence/no duplicate header");
            session.settings(true, false, 0, 0, 0);
            Progress progress;
            log << "  " << session.threads(64, progress) << '\n';
            log << "  " << session.processes(128, progress) << '\n';
            Progress cancelled;
            cancelled.cancel = true;
            bool stopped = false;
            try { session.processes(16, cancelled); } catch (const std::exception&) { stopped = true; }
            expect(stopped, "Cancel process action and reap its child");
            log << "  " << session.benchmark(1000, progress) << '\n';
            session.logger()->flush();
            if (encrypted) {
                const auto first = fs::u8path(session.path()) / fs::u8path(field(session.files().front(), "name"));
                std::ifstream input(first, std::ios::binary);
                const std::string bytes((std::istreambuf_iterator<char>(input)), {});
                expect(bytes.find(marker) == std::string::npos, "AES must hide plaintext marker");
                Records wrong;
                mxlogger::util::mxlogger_util::select_log_form_path(first.u8string().c_str(), &wrong, "wrong-key-123456", config.crypt_iv());
                expect(!wrong.empty() && field(wrong.front(), "error_code") == "1", "Wrong key detection");
            }
            // Check the safety guard while the original session remains usable.
            auto incorrect = config; incorrect.encrypted = !encrypted;
            bool rejected = false;
            try { Session mismatch(incorrect); }
            catch (const std::exception& error) { rejected = std::string(error.what()).find("Cannot decode") != std::string::npos; }
            expect(rejected, "Reject incompatible encryption settings");
            session.write(1, "still alive", "after-rejected-config");
            expect(count_tag(session.all_records(), "after-rejected-config") == 1, "Original session remains usable");

            const auto directory = fs::u8path(session.path());
            const auto current = directory / fs::u8path(field(session.files().back(), "name"));
            const auto ancient = directory / "ancient.mx";
            fs::copy_file(current, ancient);
            fs::last_write_time(ancient, fs::file_time_type::clock::now() - std::chrono::hours(24 * 10));
            session.settings(true, false, 0, 24 * 3600, 0);
            session.logger()->remove_expire_data();
            expect(!fs::exists(ancient) && fs::exists(current), "Age cleanup/current lease");
            fs::copy_file(current, directory / "size-copy.mx");
            session.settings(true, false, 0, 0, 1);
            session.logger()->remove_expire_data();
            expect(!fs::exists(directory / "size-copy.mx") && fs::exists(current), "Size cleanup/current lease");
            fs::copy_file(current, directory / "inactive.mx");
            session.logger()->remove_before_all();
            expect(session.files().size() == 1, "Keep current cleanup");
            const auto before_cleanup = session.all_records();
            fs::copy_file(current, directory / "remove-all-inactive.mx");
            session.logger()->remove_all();
            expect(session.files().size() == 1 && fs::exists(current) && !fs::exists(directory / "remove-all-inactive.mx"),
                   "Remove all deletes inactive files and preserves active mapping");
            expect(session.all_records() == before_cleanup, "Remove all preserves existing records");
            session.write(1, "after remove all", "reopen");
            expect(count_tag(session.all_records(), "reopen") == 1, "Write after removal");
            session.rebuild();
            expect(count_tag(session.all_records(), "reopen") == 1, "Rebuild after removal");
        });
    }
    test("configuration validation", [&] {
        for (const auto& value : {"../escape", "CON", "bad/name", "bad\\name", "trailing.", ""}) {
            Config config; config.root = data.u8string(); config.name_space = value;
            bool rejected = false;
            try { config.validate(); } catch (...) { rejected = true; }
            expect(rejected, "Invalid Windows namespace accepted");
        }
        Config config; config.root = data.u8string(); config.iv.clear();
        config.validate();
        auto decoded = decode_config(encode_config(config));
        expect(decoded.root == config.root && decoded.iv.empty() && decoded.key == config.key, "Worker config encoding");
    });
    cJSON_AddBoolToObject(report.get(), "passed", passed);
    cJSON_AddStringToObject(report.get(), "data_directory", data.u8string().c_str());
    cJSON_AddStringToObject(report.get(), "scope", "Shared native demo actions; Windows UI checked separately by --self-test");
    char* json = cJSON_Print(report.get());
    if (!json) throw std::runtime_error("Report JSON allocation failed");
    std::ofstream json_file(report_dir / "report.json");
    json_file << json << '\n'; cJSON_free(json);
    std::ofstream text_file(report_dir / "report.txt");
    text_file << log.str() << (passed ? "PASS\n" : "FAIL\n");
    expect(json_file.good() && text_file.good(), "Writing smoke reports failed");
    return passed ? 0 : 1;
}

} // namespace demo
