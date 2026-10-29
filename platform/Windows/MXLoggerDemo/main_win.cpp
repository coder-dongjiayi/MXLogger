#include "demo_model.hpp"
#include "mxlogger_build_config.h"
#include <windows.h>
#include <windowsx.h>
#include <commctrl.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <gdiplus.h>
#include <uxtheme.h>
#include <algorithm>
#include <ctime>
#include <cstring>
#include <cwchar>
#include <fstream>
#include <functional>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <thread>
#include <tuple>

namespace {
namespace fs = std::filesystem;
constexpr UINT done_message = WM_APP + 1;
constexpr COLORREF purple = RGB(104, 65, 217), background = RGB(245, 246, 250), ink = RGB(35, 36, 49);
enum ID {
    tab_actions = 1000, tab_config, language, open_folder, copy_path, copy_token, error_desc,
    root, browse, name_space, file_name, policy, encrypted, aes_key, aes_iv, initialize,
    enabled, console, minimum_level, max_age, max_size, apply_settings, sample_level,
    write_sample, write_json, write_token, thread_test, process_test, benchmark, flush,
    expire, keep_current, clear_all, rebuild, refresh, files_list, records_list, details,
    search, record_level, cancel_task,
    label_root, label_namespace, label_policy, label_file, label_key, label_iv,
    label_settings, label_level, label_age, label_size, label_writes, label_tests,
    label_cleanup, label_files, label_records, label_details, label_note
};
std::wstring wide(const std::string& text) {
    if (text.empty()) return {};
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
    if (!count) throw std::runtime_error("Invalid UTF-8");
    std::wstring result(static_cast<size_t>(count), L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), count);
    return result;
}
std::string utf8(const std::wstring& text) {
    if (text.empty()) return {};
    int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
    if (!count) throw std::runtime_error("Invalid Unicode text");
    std::string result(static_cast<size_t>(count), '\0');
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), count, nullptr, nullptr);
    return result;
}
std::wstring text(HWND control) {
    std::wstring value(static_cast<size_t>(GetWindowTextLengthW(control)) + 1, L'\0');
    GetWindowTextW(control, value.data(), static_cast<int>(value.size()));
    value.resize(wcslen(value.c_str())); return value;
}
std::wstring lower(std::wstring value) {
    if (!value.empty()) CharLowerBuffW(value.data(), static_cast<DWORD>(value.size()));
    return value;
}
std::wstring timestamp(const std::string& value, bool microseconds) {
    try {
        const auto raw = std::stoll(value);
        const time_t seconds = static_cast<time_t>(microseconds ? raw / 1000000 : raw);
        tm local{};
        if (localtime_s(&local, &seconds) != 0) return wide(value);
        wchar_t buffer[64]{};
        wcsftime(buffer, 64, L"%m-%d %H:%M:%S", &local);
        return buffer;
    } catch (...) { return wide(value); }
}
std::wstring default_root() {
    PWSTR local = nullptr;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_CREATE, nullptr, &local)))
        throw std::runtime_error("Cannot resolve LocalAppData");
    fs::path path(local); CoTaskMemFree(local);
    return (path / L"MXLoggerDemo" / L"Logs").wstring();
}
void clipboard(HWND window, const std::wstring& value) {
    if (!OpenClipboard(window)) throw std::runtime_error("Cannot open clipboard");
    const auto memory = GlobalAlloc(GMEM_MOVEABLE, (value.size() + 1) * sizeof(wchar_t));
    if (!memory) { CloseClipboard(); throw std::runtime_error("Clipboard allocation failed"); }
    void* bytes = GlobalLock(memory);
    if (!bytes) { GlobalFree(memory); CloseClipboard(); throw std::runtime_error("Clipboard lock failed"); }
    memcpy(bytes, value.c_str(), (value.size() + 1) * sizeof(wchar_t)); GlobalUnlock(memory);
    if (!EmptyClipboard() || !SetClipboardData(CF_UNICODETEXT, memory)) {
        GlobalFree(memory); CloseClipboard(); throw std::runtime_error("Clipboard write failed");
    }
    CloseClipboard();
}
struct Snapshot {
    demo::Config config;
    std::string path, token, error;
    long size = 0;
    demo::Records files, records;
    std::string selected_file;
    size_t record_count = 0;
    bool records_loaded = true;
};
struct Result { Snapshot snapshot; std::string message, error; };

class App {
public:
    App(bool self_test, fs::path reports) : self_test_(self_test), reports_(std::move(reports)) {
        wchar_t locale[LOCALE_NAME_MAX_LENGTH]{};
        GetUserDefaultLocaleName(locale, LOCALE_NAME_MAX_LENGTH);
        chinese_ = wcsncmp(locale, L"zh", 2) == 0;
        initial_.root = self_test_ ? (reports_ / fs::u8path("窗口数据-" + demo::unique_id())).u8string() : utf8(default_root());
        snapshot_.config = initial_;
    }
    ~App() {
        progress_.cancel = true;
        if (worker_.joinable()) worker_.join();
        session_.reset();
        logo_.reset(); if (logo_stream_) logo_stream_->Release();
        if (icon_) DestroyIcon(icon_);
        if (font_) DeleteObject(font_);
        if (heading_) DeleteObject(heading_);
        if (title_) DeleteObject(title_);
        if (white_) DeleteObject(white_);
        if (background_) DeleteObject(background_);
    }
    int run(HINSTANCE instance, int show) {
        instance_ = instance;
        WNDCLASSEXW klass{sizeof(WNDCLASSEXW)};
        klass.style = CS_HREDRAW | CS_VREDRAW;
        klass.lpfnWndProc = procedure; klass.hInstance = instance;
        klass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        klass.lpszClassName = L"MXLoggerNativeDemo";
        if (!RegisterClassExW(&klass)) throw std::runtime_error("RegisterClassExW failed");
        RECT work{}; SystemParametersInfoW(SPI_GETWORKAREA,0,&work,0);
        const auto dpi = GetDpiForSystem();
        const int width = std::min(MulDiv(1240,static_cast<int>(dpi),96),static_cast<int>(work.right-work.left)-32);
        const int height = std::min(MulDiv(860,static_cast<int>(dpi),96),static_cast<int>(work.bottom-work.top)-32);
        window_ = CreateWindowExW(0, klass.lpszClassName, L"MXLogger · Windows Native Demo", WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_VSCROLL,
                                 CW_USEDEFAULT, CW_USEDEFAULT, width, height, nullptr, nullptr, instance, this);
        if (!window_) throw std::runtime_error("CreateWindowExW failed");
        ShowWindow(window_, self_test_ ? SW_SHOWNORMAL : show); UpdateWindow(window_);
        MSG message{};
        int result;
        while ((result = GetMessageW(&message, nullptr, 0, 0)) > 0) {
            if (!IsDialogMessageW(window_, &message)) { TranslateMessage(&message); DispatchMessageW(&message); }
        }
        if (result == -1) throw std::runtime_error("GetMessageW failed");
        return static_cast<int>(message.wParam);
    }
private:
    HWND window_ = nullptr;
    HINSTANCE instance_ = nullptr;
    std::map<int, HWND> controls_;
    std::map<int, int> pages_;
    HFONT font_ = nullptr, heading_ = nullptr, title_ = nullptr;
    HBRUSH white_ = nullptr, background_ = nullptr;
    IStream* logo_stream_ = nullptr;
    std::unique_ptr<Gdiplus::Bitmap> logo_;
    HICON icon_ = nullptr;
    UINT dpi_ = 96;
    bool chinese_ = false, busy_ = false, closing_ = false, filling_ = false;
    bool self_test_ = false;
    int test_stage_ = -1, exit_code_ = 0, scroll_ = 0, operation_ = 0;
    fs::path reports_;
    demo::Config initial_;
    Snapshot snapshot_;
    std::unique_ptr<demo::Session> session_;
    std::thread worker_;
    demo::Progress progress_;
    std::wstring status_;
    std::vector<size_t> visible_records_;
    int s(int value) const { return MulDiv(value, static_cast<int>(dpi_), 96); }
    const wchar_t* tr(const wchar_t* zh, const wchar_t* en) const { return chinese_ ? zh : en; }
    HWND get(int id) const { return controls_.at(id); }
    bool checked(int id) const { return Button_GetCheck(get(id)) == BST_CHECKED; }
    int selected(int id) const { return static_cast<int>(SendMessageW(get(id), CB_GETCURSEL, 0, 0)); }
    void set(int id, const std::wstring& value) { SetWindowTextW(get(id), value.c_str()); }
    void select(int id, int index) { SendMessageW(get(id), CB_SETCURSEL, index, 0); }
    void move(int id, int x, int y, int width, int height) { MoveWindow(get(id), s(x), s(y)-scroll_, s(width), s(height), TRUE); }
    HWND create(int id, const wchar_t* klass, DWORD style, int page = -1, DWORD extended = 0) {
        HWND control = CreateWindowExW(extended, klass, L"", WS_CHILD | WS_VISIBLE | style,
            0, 0, 10, 10, window_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)), instance_, nullptr);
        if (!control) throw std::runtime_error("Cannot create native control: " + std::to_string(id));
        controls_[id] = control; pages_[id] = page;
        SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(font_), TRUE);
        return control;
    }
    void button(int id, int page = -1) { create(id, L"BUTTON", WS_TABSTOP | BS_PUSHBUTTON, page); }
    void label(int id, int page = -1) { create(id, L"STATIC", SS_LEFT, page); }
    void edit(int id, int page = -1, bool password = false) {
        create(id, L"EDIT", WS_TABSTOP | ES_AUTOHSCROLL | (password ? ES_PASSWORD : 0), page, WS_EX_CLIENTEDGE);
        SendMessageW(get(id), EM_SETLIMITTEXT, id == root ? 20000 : 256, 0);
    }
    void combo(int id, int page = -1) { create(id, WC_COMBOBOXW, WS_TABSTOP | CBS_DROPDOWNLIST | WS_VSCROLL, page); }
    void choices(int id, const std::vector<std::wstring>& values, int index) {
        SendMessageW(get(id), CB_RESETCONTENT, 0, 0);
        for (const auto& value : values) SendMessageW(get(id), CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(value.c_str()));
        select(id, index);
    }
    void fonts() {
        if (font_) DeleteObject(font_); if (heading_) DeleteObject(heading_); if (title_) DeleteObject(title_);
        font_ = CreateFontW(-s(14), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        heading_ = CreateFontW(-s(15), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        title_ = CreateFontW(-s(29), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        for (const auto& item : controls_) SendMessageW(item.second, WM_SETFONT, reinterpret_cast<WPARAM>(font_), TRUE);
    }
    void load_logo() {
        const auto resource = FindResourceW(instance_, MAKEINTRESOURCEW(101), RT_RCDATA);
        if (!resource) throw std::runtime_error("Embedded logo missing");
        const auto size = SizeofResource(instance_, resource);
        const auto loaded = LoadResource(instance_, resource);
        const auto bytes = LockResource(loaded);
        HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, size);
        if (!memory) throw std::runtime_error("Logo allocation failed");
        void* target = GlobalLock(memory);
        if (!target) { GlobalFree(memory); throw std::runtime_error("Logo lock failed"); }
        memcpy(target, bytes, size); GlobalUnlock(memory);
        if (FAILED(CreateStreamOnHGlobal(memory, TRUE, &logo_stream_))) { GlobalFree(memory); throw std::runtime_error("Logo stream failed"); }
        logo_.reset(Gdiplus::Bitmap::FromStream(logo_stream_));
        if (!logo_ || logo_->GetLastStatus() != Gdiplus::Ok) throw std::runtime_error("Cannot decode logo");
        logo_->GetHICON(&icon_);
        SendMessageW(window_, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(icon_));
        SendMessageW(window_, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(icon_));
    }
    void setup() {
        dpi_ = GetDpiForWindow(window_);
        white_ = CreateSolidBrush(RGB(255, 255, 255)); background_ = CreateSolidBrush(background);
        fonts(); load_logo();
        for (int id : {tab_actions, tab_config, language, open_folder, copy_path, copy_token, error_desc, refresh, cancel_task}) button(id);
        for (int id : {browse, initialize}) button(id, 1);
        for (int id : {apply_settings, write_sample, write_json, write_token, thread_test, process_test, benchmark, flush, expire, keep_current, clear_all, rebuild}) button(id, 0);
        for (int id : {root, name_space, file_name}) edit(id, 1);
        edit(aes_key, 1, true); edit(aes_iv, 1, true);
        combo(policy, 1);
        create(encrypted, L"BUTTON", WS_TABSTOP | BS_AUTOCHECKBOX, 1);
        for (int id : {enabled, console}) create(id, L"BUTTON", WS_TABSTOP | BS_AUTOCHECKBOX, 0);
        for (int id : {minimum_level, max_age, max_size, sample_level}) combo(id, 0);
        for (int id : {label_root, label_namespace, label_policy, label_file, label_key, label_iv, label_note}) label(id, 1);
        for (int id : {label_settings, label_level, label_age, label_size, label_writes, label_tests, label_cleanup}) label(id, 0);
        for (int id : {label_files, label_records, label_details}) label(id);
        edit(search); combo(record_level);
        SendMessageW(get(search), EM_SETLIMITTEXT, 256, 0);
        for (int id : {files_list, records_list}) {
            create(id, WC_LISTVIEWW, WS_TABSTOP | LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS, -1, WS_EX_CLIENTEDGE);
            ListView_SetExtendedListViewStyle(get(id), LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER | LVS_EX_LABELTIP);
            SetWindowTheme(get(id), L"Explorer", nullptr);
        }
        create(details, L"EDIT", WS_TABSTOP | ES_READONLY | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL, -1, WS_EX_CLIENTEDGE);
        SendMessageW(get(details), EM_SETLIMITTEXT, 4 * 1024 * 1024, 0);
        set(root, wide(initial_.root)); set(name_space, wide(initial_.name_space));
        set(file_name, wide(initial_.file_name)); set(aes_key, wide(initial_.key)); set(aes_iv, wide(initial_.iv));
        Button_SetCheck(get(encrypted), BST_CHECKED); Button_SetCheck(get(enabled), BST_CHECKED);
        choices(policy, {L"Hourly", L"Daily", L"Weekly", L"Monthly"}, 0);
        choices(minimum_level, {L"DEBUG", L"INFO", L"WARN", L"ERROR", L"FATAL"}, 0);
        choices(sample_level, {L"DEBUG", L"INFO", L"WARN", L"ERROR", L"FATAL"}, 1);
        choices(record_level, {L"All levels", L"DEBUG", L"INFO", L"WARN", L"ERROR", L"FATAL"}, 0);
        choices(max_age, {L"Unlimited", L"1 day", L"7 days", L"30 days"}, 2);
        choices(max_size, {L"Unlimited", L"1 MB", L"10 MB", L"100 MB"}, 2);
        translate(); show_page(0); layout();
        SetTimer(window_, 1, 80, nullptr);
        start(initialize);
    }
    void columns(int id, const std::vector<std::wstring>& titles) {
        HWND list = get(id);
        for (int i = Header_GetItemCount(ListView_GetHeader(list)) - 1; i >= 0; --i) ListView_DeleteColumn(list, i);
        for (size_t i = 0; i < titles.size(); ++i) {
            LVCOLUMNW column{}; column.mask = LVCF_TEXT | LVCF_WIDTH;
            column.pszText = const_cast<wchar_t*>(titles[i].c_str()); column.cx = s(100);
            ListView_InsertColumn(list, static_cast<int>(i), &column);
        }
    }
    void translate() {
        const std::vector<std::tuple<int, const wchar_t*, const wchar_t*>> labels = {
            {tab_actions,L"功能演示",L"Actions"}, {tab_config,L"初始化配置",L"Configuration"}, {language,L"English",L"中文"},
            {open_folder,L"打开目录",L"Open folder"}, {copy_path,L"复制路径",L"Copy path"}, {copy_token,L"复制 Token",L"Copy token"}, {error_desc,L"最近错误",L"Last error"},
            {label_root,L"日志根目录",L"Log root directory"}, {browse,L"选择…",L"Browse…"}, {label_namespace,L"命名空间",L"Namespace"},
            {label_policy,L"存储策略",L"Storage policy"}, {label_file,L"文件名",L"File name"}, {encrypted,L"AES-CFB-128 加密",L"AES-CFB-128 encryption"},
            {label_key,L"Key（16 UTF-8 字节）",L"Key (16 UTF-8 bytes)"}, {label_iv,L"IV（留空使用 Key）",L"IV (empty = key)"},
            {initialize,L"应用配置 / 初始化",L"Apply / initialize"}, {label_note,L"修改密钥时请使用新命名空间。\r\n参数仅用于演示，不会写入配置文件。",L"Use a new namespace when changing keys.\r\nSettings are kept only for this app session."},
            {enabled,L"开启日志写入",L"Enable logging"}, {console,L"控制台输出（Debug）",L"Console (Debug)"},
            {label_settings,L"运行设置",L"Runtime settings"}, {label_level,L"最低等级",L"Minimum level"}, {label_age,L"保留时长",L"Retention"}, {label_size,L"大小上限",L"Size limit"},
            {apply_settings,L"应用运行设置",L"Apply settings"}, {label_writes,L"日志写入",L"Write logs"}, {write_sample,L"通用日志",L"Write sample"},
            {write_json,L"网络 JSON",L"Network JSON"}, {write_token,L"Token 写入",L"Write via token"}, {label_tests,L"并发与性能（写入后校验）",L"Concurrency / performance"},
            {thread_test,L"四线程校验",L"4 threads"}, {process_test,L"双进程校验",L"2 processes"}, {benchmark,L"10 万条性能测试",L"100,000 writes"}, {flush,L"Flush 到磁盘",L"Flush to disk"},
            {label_cleanup,L"清理与生命周期",L"Cleanup / lifecycle"}, {expire,L"清理过期",L"Expired"}, {keep_current,L"仅保留当前",L"Keep current"}, {clear_all,L"删除全部",L"Remove all"},
            {rebuild,L"销毁并重建实例",L"Destroy and rebuild"}, {refresh,L"刷新",L"Refresh"}, {label_files,L"日志文件",L"Log files"},
            {label_records,L"日志浏览器 · 最近 1,000 条",L"Log viewer · latest 1,000 records"}, {label_details,L"完整日志详情",L"Full record details"}, {cancel_task,L"取消",L"Cancel"}
        };
        for (const auto& value : labels) set(std::get<0>(value), tr(std::get<1>(value), std::get<2>(value)));
        const int policy_index = selected(policy), age_index = selected(max_age), size_index = selected(max_size), level_index = selected(record_level);
        choices(policy, {tr(L"按小时",L"Hourly"), tr(L"按天",L"Daily"), tr(L"按周",L"Weekly"), tr(L"按月",L"Monthly")}, policy_index);
        choices(max_age, {tr(L"不限",L"Unlimited"), tr(L"1 天",L"1 day"), tr(L"7 天",L"7 days"), tr(L"30 天",L"30 days")}, age_index);
        choices(max_size, {tr(L"不限",L"Unlimited"), L"1 MB", L"10 MB", L"100 MB"}, size_index);
        choices(record_level, {tr(L"全部等级",L"All levels"), L"DEBUG", L"INFO", L"WARN", L"ERROR", L"FATAL"}, level_index);
        SendMessageW(get(search), EM_SETCUEBANNER, TRUE, reinterpret_cast<LPARAM>(tr(L"搜索消息 / 名称 / Tag",L"Search message / name / tag")));
        columns(files_list, {tr(L"文件名",L"File"), tr(L"字节数",L"Bytes"), tr(L"修改时间",L"Modified")});
        columns(records_list, {tr(L"等级",L"Level"), tr(L"时间",L"Time"), L"Tag", tr(L"消息",L"Message")});
        render_files(); render_records(); layout(); InvalidateRect(window_, nullptr, TRUE);
    }
    void show_page(int page) {
        for (const auto& item : pages_) if (item.second >= 0) ShowWindow(get(item.first), item.second == page ? SW_SHOW : SW_HIDE);
        InvalidateRect(window_, nullptr, TRUE);
    }
    void layout() {
        if (controls_.empty()) return;
        RECT client{}; GetClientRect(window_, &client);
        const int width = MulDiv(client.right, 96, static_cast<int>(dpi_));
        const int height = std::max(800,MulDiv(client.bottom, 96, static_cast<int>(dpi_)));
        SCROLLINFO scroll{sizeof(scroll),SIF_RANGE|SIF_PAGE|SIF_POS|SIF_DISABLENOSCROLL};
        scroll.nMin=0; scroll.nMax=s(height)-1; scroll.nPage=static_cast<UINT>(client.bottom); scroll.nPos=scroll_;
        SetScrollInfo(window_,SB_VERT,&scroll,TRUE); scroll_=GetScrollPos(window_,SB_VERT);
        const int right = 390, pane = width - right - 20;
        move(language,width-116,34,78,28);
        move(open_folder,width-430,87,94,28); move(copy_path,width-328,87,88,28);
        move(copy_token,width-232,87,94,28); move(error_desc,width-130,87,92,28);
        move(tab_actions,36,164,144,32); move(tab_config,190,164,144,32);
        move(label_settings,38,216,294,22);
        move(enabled,38,244,140,24); move(console,183,244,162,24);
        move(label_level,38,282,92,22); move(label_age,139,282,92,22); move(label_size,240,282,92,22);
        move(minimum_level,38,307,92,180); move(max_age,139,307,92,180); move(max_size,240,307,94,180);
        move(apply_settings,38,345,296,28);
        move(label_writes,38,394,296,22); move(sample_level,38,423,92,180); move(write_sample,139,423,195,29);
        move(write_json,38,461,143,29); move(write_token,191,461,143,29);
        move(label_tests,38,511,296,22); move(thread_test,38,539,143,29); move(process_test,191,539,143,29);
        move(benchmark,38,577,178,29); move(flush,226,577,108,29);
        move(label_cleanup,38,627,296,22); move(expire,38,655,92,29); move(keep_current,140,655,92,29); move(clear_all,242,655,92,29);
        move(rebuild,38,694,296,29);
        move(label_root,38,219,296,22); move(root,38,246,222,29); move(browse,268,246,66,29);
        move(label_namespace,38,294,296,22); move(name_space,38,320,296,29);
        move(label_policy,38,366,142,22); move(label_file,191,366,143,22);
        move(policy,38,392,143,180); move(file_name,191,392,143,29);
        move(encrypted,38,441,296,26); move(label_key,38,480,296,22); move(aes_key,38,506,296,29);
        move(label_iv,38,550,296,22); move(aes_iv,38,576,296,29); move(initialize,38,625,296,32); move(label_note,38,676,296,64);
        move(label_files,right+16,166,pane-132,24); move(refresh,width-116,163,78,29);
        move(files_list,right+16,204,pane-32,120);
        move(label_records,right+16,365,pane-32,24);
        move(record_level,right+16,400,110,180); move(search,right+138,400,pane-154,29);
        const int list_height = std::max(100, (height - 532) / 2);
        move(records_list,right+16,440,pane-32,list_height);
        move(label_details,right+16,452+list_height,pane-32,22);
        move(details,right+16,482+list_height,pane-32,std::max(55,height-548-list_height));
        move(cancel_task,width-110,height-42,90,28);
        ListView_SetColumnWidth(get(files_list),0,s(std::max(150,pane-298)));
        ListView_SetColumnWidth(get(files_list),1,s(90)); ListView_SetColumnWidth(get(files_list),2,s(150));
        const int widths[] = {64,124,118,std::max(120,pane-360)};
        for (int i = 0; i < 4; ++i) ListView_SetColumnWidth(get(records_list),i,s(widths[i]));
    }
    void paint(HDC dc) {
        RECT client{}; GetClientRect(window_, &client);
        FillRect(dc, &client, background_);
        const int width = MulDiv(client.right,96,static_cast<int>(dpi_));
        const int height = std::max(800,MulDiv(client.bottom,96,static_cast<int>(dpi_)));
        const int saved=SaveDC(dc); SetViewportOrgEx(dc,0,-scroll_,nullptr);
        auto card = [&](int x,int y,int w,int h,COLORREF fill) {
            HBRUSH brush = CreateSolidBrush(fill); HGDIOBJ old_brush = SelectObject(dc,brush);
            HPEN pen = CreatePen(PS_SOLID,1,fill); HGDIOBJ old_pen = SelectObject(dc,pen);
            RoundRect(dc,s(x),s(y),s(x+w),s(y+h),s(18),s(18));
            SelectObject(dc,old_pen); SelectObject(dc,old_brush); DeleteObject(pen); DeleteObject(brush);
        };
        card(20,20,width-40,114,purple);
        card(20,150,350,height-210,RGB(255,255,255));
        card(390,150,width-410,190,RGB(255,255,255));
        card(390,352,width-410,height-412,RGB(255,255,255));
        if (logo_) { Gdiplus::Graphics graphics(dc); graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic); graphics.DrawImage(logo_.get(),s(36),s(37),s(74),s(74)); }
        SetBkMode(dc,TRANSPARENT); SetTextColor(dc,RGB(255,255,255));
        auto draw = [&](const std::wstring& value, int x,int y,int w,int h, HFONT font) {
            auto old = SelectObject(dc,font); RECT rect{s(x),s(y),s(x+w),s(y+h)};
            DrawTextW(dc,value.c_str(),-1,&rect,DT_LEFT|DT_SINGLELINE|DT_END_ELLIPSIS|DT_VCENTER);
            SelectObject(dc,old);
        };
        draw(L"MXLogger",124,32,width-270,38,title_);
        const auto subtitle = snapshot_.path.empty() ? std::wstring(tr(L"Windows 原生 Demo · 初始化中",L"Windows native demo · initializing")) :
            std::wstring(snapshot_.config.encrypted ? L"AES-CFB-128" : L"Plaintext") + L"  ·  " +
            (snapshot_.config.enabled ? tr(L"写入已开启",L"Logging enabled") : tr(L"写入已关闭",L"Logging disabled")) +
            L"  ·  " + std::to_wstring(snapshot_.files.size()) + tr(L" 个文件",L" files") + L"  ·  " + std::to_wstring(snapshot_.size) + L" B";
        draw(subtitle,124,74,std::max(180,width-570),24,font_);
        draw(wide(snapshot_.path),124,101,std::max(180,width-570),20,font_);
        SetTextColor(dc,ink);
        std::wstring status = status_;
        if (busy_ && operation_ != benchmark) status += L"  " + std::to_wstring(progress_.completed.load()) + L" / " + std::to_wstring(progress_.total.load());
        draw(status,22,height-44,width-150,30,font_);
        RestoreDC(dc,saved);
    }
    demo::Config configuration() const {
        auto config = snapshot_.config;
        config.root = utf8(text(get(root))); config.name_space = utf8(text(get(name_space)));
        config.file_name = utf8(text(get(file_name)));
        static const char* policies[] = {"yyyy_MM_dd_HH","yyyy_MM_dd","yyyy_ww","yyyy_MM"};
        config.policy = policies[std::clamp(selected(policy),0,3)];
        config.encrypted = checked(encrypted); config.key = utf8(text(get(aes_key))); config.iv = utf8(text(get(aes_iv)));
        config.validate(); return config;
    }
    void controls_enabled() {
        for (const auto& control : controls_) {
            const int id = control.first;
            bool enable = !busy_;
            if (id == language || id == tab_actions || id == tab_config) enable = !(busy_ && operation_ == benchmark);
            if (id == cancel_task) enable = busy_ && !closing_ && operation_ != benchmark;
            if (id == console) enable = !busy_ && MXLOGGER_CONSOLE_ENABLED;
            if (id == aes_key || id == aes_iv) enable = !busy_ && checked(encrypted);
            EnableWindow(control.second, enable);
        }
    }
    Snapshot capture(std::string selected_file, bool load_records = true) {
        Snapshot result;
        result.config = session_->config(); result.path = session_->path(); result.token = session_->token();
        result.size = session_->logger()->dir_size();
        const char* error = session_->logger()->error_desc(); result.error = error ? error : "";
        result.files = session_->files();
        bool found = false;
        for (const auto& file : result.files) if (demo::field(file,"name") == selected_file) found = true;
        if (!found && !result.files.empty()) selected_file = demo::field(result.files.back(),"name");
        result.selected_file = selected_file;
        result.records_loaded = load_records;
        if (load_records && !result.files.empty()) {
            result.records = session_->read(selected_file); result.record_count = result.records.size();
            if (result.records.size() > 1000) result.records.erase(result.records.begin(),result.records.end()-1000);
        }
        return result;
    }
    void start(int operation) {
        if (busy_) return;
        auto config = operation == initialize ? configuration() : snapshot_.config;
        if (operation == apply_settings) {
            config.enabled = checked(enabled); config.console = checked(console); config.level = selected(minimum_level);
            static const long ages[] = {0,86400,7*86400,30*86400}, sizes[] = {0,1024*1024,10*1024*1024,100*1024*1024};
            config.max_age = ages[std::clamp(selected(max_age),0,3)]; config.max_size = sizes[std::clamp(selected(max_size),0,3)];
        }
        const int level = std::clamp(selected(sample_level),0,4);
        const auto file = snapshot_.selected_file;
        operation_ = operation;
        busy_ = true; progress_.cancel = false; progress_.completed = 0; progress_.total = 0;
        status_ = tr(L"正在执行…",L"Working…"); controls_enabled(); InvalidateRect(window_,nullptr,TRUE);
        if (operation == benchmark) {
            // Paint the initial state before starting the clock. No timer,
            // progress reporting or per-record cancellation polling during it.
            KillTimer(window_,1);
            RedrawWindow(window_,nullptr,nullptr,RDW_INVALIDATE|RDW_UPDATENOW|RDW_ALLCHILDREN);
        }
        try {
          worker_ = std::thread([this,operation,config,level,file] {
            auto result = std::make_unique<Result>();
            try {
                if (operation == initialize) {
                    auto previous = session_ ? std::make_unique<demo::Config>(session_->config()) : nullptr;
                    session_.reset();
                    try { session_ = std::make_unique<demo::Session>(config); }
                    catch (...) {
                        if (previous) session_ = std::make_unique<demo::Session>(*previous, false);
                        throw;
                    }
                } else {
                    if (!session_) throw std::runtime_error("Initialize the logger first / 请先初始化日志");
                    switch (operation) {
                        case apply_settings: session_->settings(config.enabled,config.console,config.level,config.max_age,config.max_size); break;
                        case write_sample: session_->sample(level); break;
                        case write_json: session_->sample(level,true); break;
                        case write_token: session_->sample(level,false,true); break;
                        case thread_test: result->message = session_->threads(self_test_ ? 32 : 1000,progress_); break;
                        case process_test: result->message = session_->processes(self_test_ ? 64 : 1000,progress_); break;
                        case benchmark: result->message = session_->benchmark(self_test_ ? 500 : 100000,progress_); break;
                        case flush: session_->logger()->flush(); break;
                        case expire: session_->logger()->remove_expire_data(); break;
                        case keep_current: session_->logger()->remove_before_all(); break;
                        case clear_all: session_->logger()->remove_all(); break;
                        case rebuild: session_->rebuild(); break;
                        default: break;
                    }
                }
                result->snapshot = capture(file,operation != benchmark);
                if (result->message.empty()) {
                    result->message = "OK / 完成";
                    if (operation == write_sample || operation == write_json || operation == write_token)
                        result->message = !config.enabled || level < config.level ? "Filtered by logger settings / 已被开关或等级设置过滤" : "Record written / 日志已写入";
                }
            } catch (const std::exception& error) {
                result->error = error.what();
                try { if (session_) result->snapshot = capture(file,operation != benchmark); } catch (...) {}
            }
            if (PostMessageW(window_,done_message,0,reinterpret_cast<LPARAM>(result.get()))) result.release();
          });
        } catch (...) { busy_=false; operation_=0; SetTimer(window_,1,80,nullptr); controls_enabled(); throw; }
    }
    void item(int id,int row,int column,const std::wstring& value) {
        if (column == 0) {
            LVITEMW entry{}; entry.mask = LVIF_TEXT; entry.iItem = row; entry.pszText = const_cast<wchar_t*>(value.c_str());
            ListView_InsertItem(get(id),&entry);
        } else ListView_SetItemText(get(id),row,column,const_cast<wchar_t*>(value.c_str()));
    }
    void render_files() {
        filling_ = true;
        ListView_DeleteAllItems(get(files_list));
        for (size_t i=0;i<snapshot_.files.size();++i) {
            const auto& file = snapshot_.files[i];
            item(files_list,static_cast<int>(i),0,wide(demo::field(file,"name")));
            item(files_list,static_cast<int>(i),1,wide(demo::field(file,"size")));
            item(files_list,static_cast<int>(i),2,timestamp(demo::field(file,"last_timestamp"),false));
            if (demo::field(file,"name") == snapshot_.selected_file) ListView_SetItemState(get(files_list),static_cast<int>(i),LVIS_SELECTED|LVIS_FOCUSED,LVIS_SELECTED|LVIS_FOCUSED);
        }
        filling_ = false;
    }
    void render_records() {
        filling_ = true;
        ListView_DeleteAllItems(get(records_list)); visible_records_.clear();
        if (!snapshot_.records_loaded) {
            filling_ = false;
            set(label_records,tr(L"日志浏览器 · 点击刷新加载",L"Log viewer · refresh to load"));
            set(details,tr(L"性能测试已完成。点击“刷新”读取日志。",L"Benchmark completed. Click Refresh to read the logs."));
            return;
        }
        const auto query = lower(text(get(search))); const int level = selected(record_level) - 1;
        static const wchar_t* names[] = {L"DEBUG",L"INFO",L"WARN",L"ERROR",L"FATAL"};
        for (size_t i = snapshot_.records.size(); i > 0; --i) {
            const auto& record = snapshot_.records[i-1];
            const auto raw_level = demo::field(record,"level");
            if (level >= 0 && raw_level != std::to_string(level)) continue;
            const auto haystack = lower(wide(demo::field(record,"msg") + " " + demo::field(record,"name") + " " + demo::field(record,"tag")));
            if (!query.empty() && haystack.find(query) == std::wstring::npos) continue;
            int row = static_cast<int>(visible_records_.size()); visible_records_.push_back(i-1);
            int record_level_value = raw_level.size()==1 && raw_level[0]>='0' && raw_level[0]<='4' ? raw_level[0]-'0' : -1;
            item(records_list,row,0,demo::field(record,"error_code") != "0" ? L"CORRUPT" : record_level_value>=0 ? names[record_level_value] : L"—");
            item(records_list,row,1,timestamp(demo::field(record,"timestamp"),true));
            item(records_list,row,2,wide(demo::field(record,"tag")));
            auto message = wide(demo::field(record,"msg"));
            std::replace(message.begin(),message.end(),L'\n',L' '); std::replace(message.begin(),message.end(),L'\r',L' ');
            if (message.size()>220) message.resize(220);
            item(records_list,row,3,message);
        }
        filling_ = false;
        if (!visible_records_.empty()) { ListView_SetItemState(get(records_list),0,LVIS_SELECTED|LVIS_FOCUSED,LVIS_SELECTED|LVIS_FOCUSED); show_record(0); }
        else set(details,tr(L"暂无匹配日志。",L"No matching records."));
        set(label_records,std::wstring(tr(L"日志浏览器",L"Log viewer")) + L" · " + std::to_wstring(visible_records_.size()) + L" / " + std::to_wstring(snapshot_.record_count) + tr(L"（最近 1,000 条）",L" (latest 1,000)"));
    }
    void show_record(int index) {
        if (index<0 || static_cast<size_t>(index)>=visible_records_.size()) return;
        const auto& record = snapshot_.records[visible_records_[static_cast<size_t>(index)]];
        std::wstring value;
        for (const auto& key : {"error_code","timestamp","level","name","tag","thread_id","is_main_thread"})
            value += wide(key) + L": " + wide(demo::field(record,key)) + L"\r\n";
        value += L"\r\n" + wide(demo::field(record,"msg")); set(details,value);
    }
    void completed(std::unique_ptr<Result> result) {
        if (worker_.joinable()) worker_.join();
        busy_ = false;
        operation_ = 0;
        if (!closing_) SetTimer(window_,1,80,nullptr);
        if (!result->snapshot.path.empty()) snapshot_ = std::move(result->snapshot);
        status_ = wide(result->error.empty() ? result->message : result->error);
        Button_SetCheck(get(enabled),snapshot_.config.enabled ? BST_CHECKED : BST_UNCHECKED);
        Button_SetCheck(get(console),snapshot_.config.console ? BST_CHECKED : BST_UNCHECKED);
        select(minimum_level,snapshot_.config.level);
        render_files(); render_records(); controls_enabled(); InvalidateRect(window_,nullptr,TRUE);
        if (closing_) { DestroyWindow(window_); return; }
        if (!result->error.empty()) {
            if (self_test_) { fail_test(result->error); return; }
            MessageBoxW(window_,status_.c_str(),L"MXLogger",MB_OK|MB_ICONERROR);
        }
    }
    void browse_folder() {
        IFileDialog* dialog = nullptr;
        if (FAILED(CoCreateInstance(CLSID_FileOpenDialog,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&dialog)))) throw std::runtime_error("Folder picker unavailable");
        DWORD options = 0; dialog->GetOptions(&options); dialog->SetOptions(options|FOS_PICKFOLDERS|FOS_FORCEFILESYSTEM);
        dialog->SetTitle(tr(L"选择日志根目录",L"Choose a log root directory"));
        if (SUCCEEDED(dialog->Show(window_))) {
            IShellItem* folder = nullptr;
            if (SUCCEEDED(dialog->GetResult(&folder))) {
                PWSTR path = nullptr;
                if (SUCCEEDED(folder->GetDisplayName(SIGDN_FILESYSPATH,&path))) { set(root,path); CoTaskMemFree(path); }
                folder->Release();
            }
        }
        dialog->Release();
    }
    void command(int id,int notification) {
        if (id == language) { chinese_ = !chinese_; translate(); return; }
        if (id == tab_actions || id == tab_config) { show_page(id==tab_actions ? 0 : 1); return; }
        if (id == cancel_task) { progress_.cancel = true; status_=tr(L"正在取消…",L"Cancelling…"); return; }
        if (busy_) return;
        if (id == search && notification == EN_CHANGE) { render_records(); return; }
        if (id == record_level && notification == CBN_SELCHANGE) { render_records(); return; }
        if (id == encrypted) { controls_enabled(); return; }
        if (id == browse) { browse_folder(); return; }
        if (id == open_folder) {
            if (snapshot_.path.empty()) return;
            if (reinterpret_cast<INT_PTR>(ShellExecuteW(window_,L"open",wide(snapshot_.path).c_str(),nullptr,nullptr,SW_SHOWNORMAL))<=32)
                throw std::runtime_error("Cannot open log directory");
            return;
        }
        if (id == copy_path || id == copy_token) { clipboard(window_,wide(id==copy_path ? snapshot_.path : snapshot_.token)); return; }
        if (id == error_desc) { MessageBoxW(window_,snapshot_.error.empty() ? tr(L"暂无错误",L"No errors recorded") : wide(snapshot_.error).c_str(),L"MXLogger",MB_OK); return; }
        if ((id == clear_all || id == keep_current || id == expire) && !self_test_) {
            if (MessageBoxW(window_,tr(L"确定执行此清理操作？已删除的日志无法恢复。",L"Run this cleanup? Deleted logs cannot be restored."),L"MXLogger",MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2)!=IDYES) return;
        }
        switch (id) {
            case initialize: case apply_settings: case write_sample: case write_json: case write_token:
            case thread_test: case process_test: case benchmark: case flush: case expire: case keep_current:
            case clear_all: case rebuild: case refresh: start(id); break;
            default: break;
        }
    }
    void capture_png(const fs::path& path) {
        RECT client{}; GetClientRect(window_,&client);
        HDC screen = GetDC(window_), memory = CreateCompatibleDC(screen);
        HBITMAP bitmap = CreateCompatibleBitmap(screen,client.right,client.bottom);
        auto old = SelectObject(memory,bitmap);
        SendMessageW(window_,WM_PRINT,reinterpret_cast<WPARAM>(memory),PRF_CLIENT|PRF_CHILDREN|PRF_ERASEBKGND);
        const bool painted = GetPixel(memory,s(25),s(80)-scroll_) == purple;
        SelectObject(memory,old); DeleteDC(memory); ReleaseDC(window_,screen);
        UINT count=0, size=0; Gdiplus::GetImageEncodersSize(&count,&size);
        std::vector<unsigned char> storage(size);
        auto* encoders = reinterpret_cast<Gdiplus::ImageCodecInfo*>(storage.data());
        Gdiplus::GetImageEncoders(count,size,encoders);
        bool saved = false;
        {
            Gdiplus::Bitmap image(bitmap,nullptr);
            for (UINT i=0;i<count;++i) if (wcscmp(encoders[i].MimeType,L"image/png")==0)
                saved = image.Save(path.c_str(),&encoders[i].Clsid,nullptr)==Gdiplus::Ok;
        }
        DeleteObject(bitmap);
        if (!saved || !painted) throw std::runtime_error("Window screenshot was not rendered correctly");
    }
    void fail_test(const std::string& message) {
        std::ofstream log(reports_/"ui-report.txt",std::ios::app); log << "FAIL stage " << test_stage_ << ": " << message << '\n';
        try { capture_png(reports_/L"failure.png"); } catch (...) {}
        self_test_ = false;
        exit_code_ = 1;
        DestroyWindow(window_);
    }
    void self_test_tick() {
        if (!self_test_ || busy_) return;
        auto expect = [](bool value,const char* message) { if (!value) throw std::runtime_error(message); };
        auto click = [&](int id) { SendMessageW(get(id),BM_CLICK,0,0); };
        switch (test_stage_++) {
            case -1:
                expect(!snapshot_.path.empty(),"UI initialization"); click(tab_config);
                set(name_space,L"com.djy.mxlogger.ui"); click(initialize); break;
            case 0: expect(snapshot_.config.name_space=="com.djy.mxlogger.ui","Configuration controls -> Core"); click(tab_actions); click(write_sample); break;
            case 1: click(write_json); break;
            case 2: click(write_token); break;
            case 3: Button_SetCheck(get(enabled),BST_UNCHECKED); click(apply_settings); break;
            case 4: expect(!snapshot_.config.enabled,"Enable checkbox -> Core"); click(write_sample); break;
            case 5: expect(snapshot_.record_count==4,"Disabled UI write must not append"); Button_SetCheck(get(enabled),BST_CHECKED); click(apply_settings); break;
            case 6: select(minimum_level,3); click(apply_settings); break;
            case 7: click(write_sample); break;
            case 8: expect(snapshot_.record_count==4,"Minimum-level UI filter"); select(minimum_level,0); click(apply_settings); break;
            case 9: click(rebuild); break;
            case 10: expect(snapshot_.record_count==4,"UI rebuild persistence/header"); click(thread_test); break;
            case 11: click(process_test); break;
            case 12:
                click(benchmark);
                expect(!IsWindowEnabled(get(cancel_task)),"Benchmark must not offer per-record cancellation"); break;
            case 13:
                expect(!snapshot_.records_loaded && ListView_GetItemCount(get(records_list))==0,"Benchmark must defer preview loading");
                click(refresh); break;
            case 14: {
                expect(ListView_GetItemCount(get(files_list))>0 && ListView_GetItemCount(get(records_list))>0,"File/record browser");
                expect(text(get(details)).find(L"thread_id:")!=std::wstring::npos,"Full record details");
                expect(IsWindowEnabled(get(console)) == static_cast<BOOL>(MXLOGGER_CONSOLE_ENABLED),"Release console availability");
                set(search,L"no-match-"+wide(demo::unique_id()));
                expect(ListView_GetItemCount(get(records_list))==0,"Search filter");
                set(search,L"");
                expect(ListView_GetItemCount(get(records_list))>0,"Search reset");
                select(record_level,5); command(record_level,CBN_SELCHANGE);
                expect(ListView_GetItemCount(get(records_list))==0,"Viewer level filter");
                select(record_level,0); command(record_level,CBN_SELCHANGE);
                expect(ListView_GetItemCount(get(records_list))>0,"Viewer level reset");
                chinese_=false; translate(); capture_png(reports_/L"actions-en.png");
                click(language); capture_png(reports_/L"actions-zh.png");
                click(tab_config); capture_png(reports_/L"configuration-zh.png");
                click(tab_actions); click(clear_all); break;
            }
            case 15: expect(snapshot_.files.empty(),"Remove-all button"); click(write_sample); break;
            case 16: expect(snapshot_.record_count==1,"UI write after removal"); click(rebuild); break;
            default: {
                expect(snapshot_.record_count==1,"UI reopen after removal");
                std::ofstream log(reports_/"ui-report.txt",std::ios::app);
                log << "PASS native controls, settings, file/record viewer, filtering, concurrency, cleanup, languages\n";
                if (!log.good()) throw std::runtime_error("UI report write failed");
                self_test_=false; DestroyWindow(window_); break;
            }
        }
    }
    LRESULT message(UINT message,WPARAM wp,LPARAM lp) {
        switch (message) {
            case WM_CREATE: setup(); return 0;
            case WM_SIZE: layout(); return 0;
            case WM_GETMINMAXINFO: {
                auto* limits=reinterpret_cast<MINMAXINFO*>(lp);
                limits->ptMinTrackSize={s(1060),s(480)}; return 0;
            }
            case WM_DPICHANGED: {
                dpi_=HIWORD(wp); fonts(); auto* bounds=reinterpret_cast<RECT*>(lp);
                SetWindowPos(window_,nullptr,bounds->left,bounds->top,bounds->right-bounds->left,bounds->bottom-bounds->top,SWP_NOZORDER|SWP_NOACTIVATE);
                layout(); return 0;
            }
            case WM_VSCROLL: {
                SCROLLINFO info{sizeof(info),SIF_ALL}; GetScrollInfo(window_,SB_VERT,&info);
                int position=scroll_;
                switch (LOWORD(wp)) {
                    case SB_LINEUP: position-=s(32); break;
                    case SB_LINEDOWN: position+=s(32); break;
                    case SB_PAGEUP: position-=static_cast<int>(info.nPage); break;
                    case SB_PAGEDOWN: position+=static_cast<int>(info.nPage); break;
                    case SB_THUMBTRACK: position=info.nTrackPos; break;
                    case SB_TOP: position=0; break;
                    case SB_BOTTOM: position=info.nMax; break;
                    default: return 0;
                }
                SetScrollPos(window_,SB_VERT,position,TRUE); scroll_=GetScrollPos(window_,SB_VERT);
                layout(); InvalidateRect(window_,nullptr,TRUE); return 0;
            }
            case WM_MOUSEWHEEL:
                SetScrollPos(window_,SB_VERT,scroll_-MulDiv(GET_WHEEL_DELTA_WPARAM(wp),s(72),WHEEL_DELTA),TRUE);
                scroll_=GetScrollPos(window_,SB_VERT); layout(); InvalidateRect(window_,nullptr,TRUE); return 0;
            case WM_PAINT: { PAINTSTRUCT ps; HDC dc=BeginPaint(window_,&ps); paint(dc); EndPaint(window_,&ps); return 0; }
            case WM_PRINTCLIENT: paint(reinterpret_cast<HDC>(wp)); return 0;
            case WM_ERASEBKGND: return 1;
            case WM_CTLCOLORSTATIC: {
                HDC dc=reinterpret_cast<HDC>(wp); SetBkColor(dc,RGB(255,255,255)); SetTextColor(dc,ink); return reinterpret_cast<LRESULT>(white_);
            }
            case WM_COMMAND: command(LOWORD(wp),HIWORD(wp)); return 0;
            case WM_NOTIFY: {
                const auto* notification=reinterpret_cast<NMHDR*>(lp);
                if (notification->code==LVN_ITEMCHANGED && !filling_ && !busy_) {
                    const auto* change=reinterpret_cast<NMLISTVIEW*>(lp);
                    if ((change->uChanged&LVIF_STATE) && (change->uNewState&LVIS_SELECTED)) {
                        if (notification->idFrom==files_list && change->iItem>=0 && static_cast<size_t>(change->iItem)<snapshot_.files.size()) {
                            snapshot_.selected_file=demo::field(snapshot_.files[static_cast<size_t>(change->iItem)],"name"); start(refresh);
                        } else if (notification->idFrom==records_list) show_record(change->iItem);
                    }
                }
                return 0;
            }
            case done_message: completed(std::unique_ptr<Result>(reinterpret_cast<Result*>(lp))); return 0;
            case WM_TIMER:
                if (busy_ && operation_ == benchmark) return 0;
                if (busy_) { RECT rect{}; GetClientRect(window_,&rect); rect.top=std::max(s(800),static_cast<int>(rect.bottom))-scroll_-s(50); InvalidateRect(window_,&rect,FALSE); }
                self_test_tick(); return 0;
            case WM_CLOSE:
                if (busy_) { closing_=true; progress_.cancel=true; controls_enabled(); return 0; }
                DestroyWindow(window_); return 0;
            case WM_DESTROY: KillTimer(window_,1); PostQuitMessage(exit_code_); return 0;
            default: return DefWindowProcW(window_,message,wp,lp);
        }
    }
    static LRESULT CALLBACK procedure(HWND window,UINT message,WPARAM wp,LPARAM lp) {
        App* app=reinterpret_cast<App*>(GetWindowLongPtrW(window,GWLP_USERDATA));
        if (message==WM_NCCREATE) {
            app=static_cast<App*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);
            app->window_=window; SetWindowLongPtrW(window,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(app));
        }
        if (!app) return DefWindowProcW(window,message,wp,lp);
        try { return app->message(message,wp,lp); }
        catch (const std::exception& error) {
            if (app->self_test_) app->fail_test(error.what());
            else MessageBoxW(window,wide(error.what()).c_str(),L"MXLogger",MB_OK|MB_ICONERROR);
            return message==WM_CREATE ? -1 : 0;
        }
    }
};
} // namespace

int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR,int show) {
    int count=0;
    LPWSTR* raw=CommandLineToArgvW(GetCommandLineW(),&count);
    if (!raw) return 1;
    std::vector<std::wstring> arguments(raw,raw+count); LocalFree(raw);
    if (count==4 && arguments[1]==L"--worker") return demo::run_worker(utf8(arguments[2]),utf8(arguments[3]));
    bool self_test=false; fs::path reports;
    if (count!=1) {
        if (count!=4 || arguments[1]!=L"--self-test" || arguments[2]!=L"--report-dir") {
            MessageBoxW(nullptr,L"Usage: MXLoggerDemo.exe [--self-test --report-dir <directory>]",L"MXLogger",MB_OK|MB_ICONERROR); return 2;
        }
        self_test=true; reports=fs::absolute(arguments[3]);
    }
    const HRESULT com=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
    if (FAILED(com)) return 1;
    Gdiplus::GdiplusStartupInput graphics_input;
    ULONG_PTR graphics=0;
    if (Gdiplus::GdiplusStartup(&graphics,&graphics_input,nullptr)!=Gdiplus::Ok) { CoUninitialize(); return 1; }
    INITCOMMONCONTROLSEX controls{sizeof(controls),ICC_LISTVIEW_CLASSES|ICC_STANDARD_CLASSES}; InitCommonControlsEx(&controls);
    int result=1;
    try {
        if (self_test) {
            fs::create_directories(reports);
            std::ofstream(reports/"ui-report.txt") << "Native Win32 window/control smoke\n";
            if (demo::smoke(reports/"model")!=0) throw std::runtime_error("Demo action smoke failed; see model/report.txt");
        }
        App app(self_test,reports); result=app.run(instance,show);
    } catch (const std::exception& error) {
        if (self_test) { std::ofstream log(reports/"ui-report.txt",std::ios::app); log << "FAIL " << error.what() << '\n'; }
        else MessageBoxW(nullptr,wide(error.what()).c_str(),L"MXLogger",MB_OK|MB_ICONERROR);
    }
    Gdiplus::GdiplusShutdown(graphics); CoUninitialize(); return result;
}
