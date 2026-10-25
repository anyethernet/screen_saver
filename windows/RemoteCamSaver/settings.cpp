#include "settings.h"

#include "stream.h"
#include "tailscale.h"
#include "util.h"

#include <commctrl.h>
#include <cstring>
#include <process.h>
#include <vector>
#include <wincrypt.h>

#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "crypt32.lib")
#pragma comment(lib, "comctl32.lib")

namespace {

constexpr wchar_t kKeyPath[] = L"Software\\RemoteCamSaver";
constexpr int IDC_URL = 1001;
constexpr int IDC_TOKEN = 1002;
constexpr int IDC_SHOWTOKEN = 1003;
constexpr int IDC_FILL = 1004;
constexpr int IDC_INSECURE = 1005;
constexpr int IDC_TEST = 1006;
constexpr int IDC_STATUS = 1007;
constexpr int IDC_TS_STATUS = 1008;
constexpr int IDC_TS_UP = 1009;
constexpr int IDC_TS_DOWN = 1010;
constexpr int IDC_TS_HELP = 1011;
constexpr int IDC_GUIDE_TEXT = 1101;
constexpr UINT WM_APP_TEST = WM_APP + 1;
constexpr UINT WM_APP_TAILSCALE = WM_APP + 2;

struct DialogState {
    Settings settings;
    HWND hwnd = nullptr;
    std::atomic<bool> stop{false};
    std::atomic<bool> closing{false};
    HANDLE thread = nullptr;
    HANDLE tailscaleThread = nullptr;
    HANDLE tailscaleProcess = nullptr;
    std::atomic<bool> tailscaleStop{false};
    CRITICAL_SECTION postLock;
    RequestSlot slot;

    DialogState() { InitializeCriticalSection(&postLock); }
    ~DialogState() { DeleteCriticalSection(&postLock); }
};

struct TestJob {
    StreamConfig config;
    DialogState* state = nullptr;
};

struct TailscaleJob {
    DialogState* state = nullptr;
    TailscaleAction action = TailscaleAction::Status;
};

void AddWord(std::vector<unsigned char>& buffer, WORD value) {
    buffer.push_back(static_cast<unsigned char>(value & 0xFF));
    buffer.push_back(static_cast<unsigned char>((value >> 8) & 0xFF));
}

void AddDword(std::vector<unsigned char>& buffer, DWORD value) {
    AddWord(buffer, static_cast<WORD>(value & 0xFFFF));
    AddWord(buffer, static_cast<WORD>((value >> 16) & 0xFFFF));
}

void AddShort(std::vector<unsigned char>& buffer, short value) {
    AddWord(buffer, static_cast<WORD>(value));
}

void AddString(std::vector<unsigned char>& buffer, const wchar_t* text) {
    const unsigned char* bytes = reinterpret_cast<const unsigned char*>(text);
    size_t size = (wcslen(text) + 1) * sizeof(wchar_t);
    buffer.insert(buffer.end(), bytes, bytes + size);
}

void Align4(std::vector<unsigned char>& buffer) {
    while (buffer.size() % 4 != 0) {
        buffer.push_back(0);
    }
}

void AddItem(
    std::vector<unsigned char>& buffer,
    int& count,
    DWORD style,
    DWORD exStyle,
    short x,
    short y,
    short cx,
    short cy,
    WORD id,
    WORD klass,
    const wchar_t* title) {
    Align4(buffer);
    AddDword(buffer, style);
    AddDword(buffer, exStyle);
    AddShort(buffer, x);
    AddShort(buffer, y);
    AddShort(buffer, cx);
    AddShort(buffer, cy);
    AddWord(buffer, id);
    AddWord(buffer, 0xFFFF);
    AddWord(buffer, klass);
    AddString(buffer, title);
    AddWord(buffer, 0);
    ++count;
}

std::vector<unsigned char> BuildSettingsTemplate() {
    constexpr DWORD kStyle = DS_SETFONT | DS_MODALFRAME | DS_CENTER | WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_VISIBLE;
    std::vector<unsigned char> buffer;
    AddDword(buffer, kStyle);
    AddDword(buffer, 0);
    AddWord(buffer, 0);
    AddShort(buffer, 0);
    AddShort(buffer, 0);
    AddShort(buffer, 312);
    AddShort(buffer, 254);
    AddWord(buffer, 0);
    AddWord(buffer, 0);
    AddString(buffer, L"원격 카메라 화면 보호기");
    AddWord(buffer, 9);
    AddString(buffer, L"Segoe UI");

    int count = 0;
    constexpr DWORD kStatic = WS_CHILD | WS_VISIBLE | SS_LEFT | SS_NOPREFIX;
    constexpr DWORD kEdit = WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL | ES_LEFT;
    constexpr DWORD kCheck = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX;
    constexpr DWORD kButton = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON;
    constexpr WORD kButtonClass = 0x0080;
    constexpr WORD kEditClass = 0x0081;
    constexpr WORD kStaticClass = 0x0082;

    AddItem(buffer, count, kStatic, 0, 8, 8, 280, 10, 0xFFFF, kStaticClass, L"영상 주소");
    AddItem(buffer, count, kEdit, WS_EX_CLIENTEDGE, 8, 20, 296, 14, IDC_URL, kEditClass, L"");
    AddItem(
        buffer,
        count,
        kStatic,
        0,
        8,
        38,
        296,
        24,
        0xFFFF,
        kStaticClass,
        L"Tailscale 주소와 공유기 포트포워딩 주소를 같은 칸에 넣습니다.\n예: http://100.64.0.2:8787/api/v1/stream.mjpeg");
    AddItem(buffer, count, kStatic, 0, 8, 66, 280, 10, 0xFFFF, kStaticClass, L"접속 토큰");
    AddItem(buffer, count, kEdit | ES_PASSWORD, WS_EX_CLIENTEDGE, 8, 78, 296, 14, IDC_TOKEN, kEditClass, L"");
    AddItem(buffer, count, kCheck, 0, 8, 98, 90, 12, IDC_SHOWTOKEN, kButtonClass, L"토큰 표시");
    AddItem(buffer, count, kCheck, 0, 8, 116, 180, 12, IDC_FILL, kButtonClass, L"화면을 채워 자르기");
    AddItem(buffer, count, kCheck, 0, 8, 134, 220, 12, IDC_INSECURE, kButtonClass, L"HTTPS 자체 서명 인증서 허용");
    AddItem(buffer, count, kStatic, 0, 8, 156, 296, 12, IDC_TS_STATUS, kStaticClass, L"Tailscale: 확인 중…");
    AddItem(buffer, count, kButton, 0, 8, 172, 64, 16, IDC_TS_UP, kButtonClass, L"연결");
    AddItem(buffer, count, kButton, 0, 78, 172, 84, 16, IDC_TS_DOWN, kButtonClass, L"연결 끊기");
    AddItem(buffer, count, kButton, 0, 170, 172, 76, 16, IDC_TS_HELP, kButtonClass, L"사용 설명");
    AddItem(buffer, count, kButton, 0, 8, 198, 72, 16, IDC_TEST, kButtonClass, L"연결 테스트");
    AddItem(buffer, count, kStatic, 0, 88, 201, 216, 12, IDC_STATUS, kStaticClass, L"");
    AddItem(buffer, count, kButton | BS_DEFPUSHBUTTON, 0, 168, 226, 64, 16, IDOK, kButtonClass, L"저장");
    AddItem(buffer, count, kButton, 0, 240, 226, 64, 16, IDCANCEL, kButtonClass, L"취소");

    buffer[8] = static_cast<unsigned char>(count & 0xFF);
    buffer[9] = static_cast<unsigned char>((count >> 8) & 0xFF);
    return buffer;
}

bool ReadStringValue(HKEY key, const wchar_t* name, std::wstring& value) {
    DWORD size = 0;
    if (RegGetValueW(key, nullptr, name, RRF_RT_REG_SZ, nullptr, nullptr, &size) != ERROR_SUCCESS || size < sizeof(wchar_t)) {
        return false;
    }
    std::wstring text(size / sizeof(wchar_t), L'\0');
    if (RegGetValueW(key, nullptr, name, RRF_RT_REG_SZ, nullptr, text.data(), &size) != ERROR_SUCCESS) {
        return false;
    }
    while (!text.empty() && text.back() == L'\0') {
        text.pop_back();
    }
    value = text;
    return true;
}

bool ReadDwordValue(HKEY key, const wchar_t* name, DWORD& value) {
    DWORD size = sizeof(value);
    return RegGetValueW(key, nullptr, name, RRF_RT_REG_DWORD, nullptr, &value, &size) == ERROR_SUCCESS;
}

unsigned __stdcall TestThread(void* param) {
    auto* job = static_cast<TestJob*>(param);
    int width = 0;
    int height = 0;
    std::wstring error = TestMjpegStream(job->config, job->state->stop, job->state->slot, width, height);
    std::wstring text;
    if (error.empty()) {
        text = L"연결됨 (" + std::to_wstring(width) + L" x " + std::to_wstring(height) + L")";
    } else {
        text = error;
    }

    EnterCriticalSection(&job->state->postLock);
    bool post = !job->state->closing.load();
    if (post) {
        PostMessageW(job->state->hwnd, WM_APP_TEST, 0, reinterpret_cast<LPARAM>(new std::wstring(text)));
    }
    LeaveCriticalSection(&job->state->postLock);
    delete job;
    return 0;
}

Settings ReadDialogSettings(HWND hwnd) {
    Settings settings;
    wchar_t url[2048]{};
    wchar_t token[512]{};
    GetDlgItemTextW(hwnd, IDC_URL, url, _countof(url));
    GetDlgItemTextW(hwnd, IDC_TOKEN, token, _countof(token));
    settings.url = TrimCopy(url);
    settings.token = TrimCopy(token);
    settings.fill = IsDlgButtonChecked(hwnd, IDC_FILL) == BST_CHECKED;
    settings.allowInsecureTls = IsDlgButtonChecked(hwnd, IDC_INSECURE) == BST_CHECKED;
    return settings;
}

void CancelTailscaleProcess(DialogState* state) {
    state->tailscaleStop = true;
    EnterCriticalSection(&state->postLock);
    HANDLE process = state->tailscaleProcess;
    if (process) {
        TerminateProcess(process, 1);
    }
    LeaveCriticalSection(&state->postLock);
}

void CloseDialog(DialogState* state, HWND hwnd, INT_PTR result) {
    EnterCriticalSection(&state->postLock);
    if (state->closing.exchange(true)) {
        LeaveCriticalSection(&state->postLock);
        return;
    }
    LeaveCriticalSection(&state->postLock);

    state->stop = true;
    state->slot.Close();
    CancelTailscaleProcess(state);
    if (state->thread) {
        WaitForSingleObject(state->thread, 5000);
        CloseHandle(state->thread);
        state->thread = nullptr;
    }
    if (state->tailscaleThread) {
        WaitForSingleObject(state->tailscaleThread, 8000);
        CloseHandle(state->tailscaleThread);
        state->tailscaleThread = nullptr;
    }
    MSG message;
    while (PeekMessageW(&message, hwnd, WM_APP_TEST, WM_APP_TEST, PM_REMOVE)) {
        delete reinterpret_cast<std::wstring*>(message.lParam);
    }
    while (PeekMessageW(&message, hwnd, WM_APP_TAILSCALE, WM_APP_TAILSCALE, PM_REMOVE)) {
        delete reinterpret_cast<std::wstring*>(message.lParam);
    }
    EndDialog(hwnd, result);
}

unsigned __stdcall TailscaleThread(void* param) {
    auto* job = static_cast<TailscaleJob*>(param);
    TailscaleCancel cancel{&job->state->postLock, &job->state->tailscaleProcess, &job->state->tailscaleStop};
    std::wstring text = PerformTailscaleAction(job->action, &cancel);
    EnterCriticalSection(&job->state->postLock);
    if (!job->state->closing.load()) {
        PostMessageW(job->state->hwnd, WM_APP_TAILSCALE, 0, reinterpret_cast<LPARAM>(new std::wstring(std::move(text))));
    }
    LeaveCriticalSection(&job->state->postLock);
    delete job;
    return 0;
}

void SetTailscaleBusy(HWND hwnd, bool busy) {
    EnableWindow(GetDlgItem(hwnd, IDC_TS_UP), busy ? FALSE : TRUE);
    EnableWindow(GetDlgItem(hwnd, IDC_TS_DOWN), busy ? FALSE : TRUE);
}

std::wstring LoadGuideText(HINSTANCE instance) {
    HRSRC resource = FindResourceW(instance, MAKEINTRESOURCEW(101), RT_RCDATA);
    if (!resource) {
        return L"설명서를 찾지 못했습니다.";
    }
    HGLOBAL loaded = LoadResource(instance, resource);
    const char* bytes = static_cast<const char*>(LockResource(loaded));
    DWORD size = SizeofResource(instance, resource);
    if (!bytes || size == 0) {
        return L"설명서를 읽지 못했습니다.";
    }
    if (size >= 3 && memcmp(bytes, "\xEF\xBB\xBF", 3) == 0) {
        bytes += 3;
        size -= 3;
    }
    int count = MultiByteToWideChar(CP_UTF8, 0, bytes, static_cast<int>(size), nullptr, 0);
    if (count <= 0) {
        return L"설명서를 읽지 못했습니다.";
    }
    std::wstring text(static_cast<size_t>(count), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, bytes, static_cast<int>(size), text.data(), count);
    return text;
}

INT_PTR CALLBACK GuideProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_INITDIALOG: {
        const auto* text = reinterpret_cast<const std::wstring*>(lParam);
        SetDlgItemTextW(hwnd, IDC_GUIDE_TEXT, text->c_str());
        SendDlgItemMessageW(hwnd, IDC_GUIDE_TEXT, EM_SETSEL, 0, 0);
        return TRUE;
    }
    case WM_COMMAND:
        if (LOWORD(wParam) == IDOK || LOWORD(wParam) == IDCANCEL) {
            EndDialog(hwnd, IDOK);
            return TRUE;
        }
        break;
    case WM_CLOSE:
        EndDialog(hwnd, IDOK);
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

void ShowTailscaleGuide(HWND parent) {
    HINSTANCE instance = GetModuleHandleW(nullptr);
    std::wstring text = LoadGuideText(instance);
    std::vector<unsigned char> buffer;
    constexpr DWORD style = DS_SETFONT | DS_MODALFRAME | DS_CENTER | WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_VISIBLE;
    AddDword(buffer, style);
    AddDword(buffer, 0);
    AddWord(buffer, 0);
    AddShort(buffer, 0);
    AddShort(buffer, 0);
    AddShort(buffer, 340);
    AddShort(buffer, 248);
    AddWord(buffer, 0);
    AddWord(buffer, 0);
    AddString(buffer, L"Tailscale 사용 설명");
    AddWord(buffer, 9);
    AddString(buffer, L"Segoe UI");

    int count = 0;
    constexpr DWORD editStyle = WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL | ES_READONLY | ES_WANTRETURN;
    constexpr DWORD buttonStyle = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON;
    AddItem(buffer, count, editStyle, WS_EX_CLIENTEDGE, 8, 8, 324, 214, IDC_GUIDE_TEXT, 0x0081, L"");
    AddItem(buffer, count, buttonStyle, 0, 262, 226, 70, 16, IDOK, 0x0080, L"닫기");
    buffer[8] = static_cast<unsigned char>(count & 0xFF);
    buffer[9] = static_cast<unsigned char>((count >> 8) & 0xFF);

    INT_PTR result = DialogBoxIndirectParamW(
        instance,
        reinterpret_cast<LPCDLGTEMPLATEW>(buffer.data()),
        parent,
        GuideProc,
        reinterpret_cast<LPARAM>(&text));
    if (result == -1) {
        wchar_t message[96];
        swprintf_s(message, L"설명 창을 열지 못했습니다. (%lu)", GetLastError());
        MessageBoxW(parent, message, L"원격 카메라", MB_ICONERROR);
    }
}

void StartTailscale(DialogState* state, HWND hwnd, TailscaleAction action) {
    if (state->closing || state->tailscaleThread) {
        return;
    }
    if (action == TailscaleAction::Connect) {
        SetDlgItemTextW(hwnd, IDC_TS_STATUS, L"Tailscale: 연결하는 중…");
    } else if (action == TailscaleAction::Disconnect) {
        SetDlgItemTextW(hwnd, IDC_TS_STATUS, L"Tailscale: 연결을 끊는 중…");
    }
    SetTailscaleBusy(hwnd, true);
    auto* job = new TailscaleJob();
    job->state = state;
    job->action = action;
    uintptr_t thread = _beginthreadex(nullptr, 0, TailscaleThread, job, 0, nullptr);
    if (!thread) {
        delete job;
        SetTailscaleBusy(hwnd, false);
        SetDlgItemTextW(hwnd, IDC_TS_STATUS, L"Tailscale: 명령을 시작하지 못했습니다");
        return;
    }
    state->tailscaleThread = reinterpret_cast<HANDLE>(thread);
}

void StartTest(DialogState* state, HWND hwnd) {
    if (state->closing || state->thread) {
        return;
    }
    Settings settings = ReadDialogSettings(hwnd);
    if (!StartsWithHttp(settings.url)) {
        SetDlgItemTextW(hwnd, IDC_STATUS, L"http:// 또는 https:// 주소가 필요합니다.");
        return;
    }
    state->stop = false;
    auto* job = new TestJob();
    job->state = state;
    job->config.url = settings.url;
    job->config.token = settings.token;
    job->config.allowInsecureTls = settings.allowInsecureTls;
    SetDlgItemTextW(hwnd, IDC_STATUS, L"확인 중…");
    EnableWindow(GetDlgItem(hwnd, IDC_TEST), FALSE);
    uintptr_t thread = _beginthreadex(nullptr, 0, TestThread, job, 0, nullptr);
    if (!thread) {
        delete job;
        EnableWindow(GetDlgItem(hwnd, IDC_TEST), TRUE);
        SetDlgItemTextW(hwnd, IDC_STATUS, L"테스트를 시작하지 못했습니다.");
        return;
    }
    state->thread = reinterpret_cast<HANDLE>(thread);
}

INT_PTR CALLBACK SettingsProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    auto* state = reinterpret_cast<DialogState*>(GetWindowLongPtrW(hwnd, DWLP_USER));
    switch (message) {
    case WM_INITDIALOG: {
        state = reinterpret_cast<DialogState*>(lParam);
        SetWindowLongPtrW(hwnd, DWLP_USER, lParam);
        state->hwnd = hwnd;
        SetDlgItemTextW(hwnd, IDC_URL, state->settings.url.c_str());
        SetDlgItemTextW(hwnd, IDC_TOKEN, state->settings.token.c_str());
        CheckDlgButton(hwnd, IDC_FILL, state->settings.fill ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hwnd, IDC_INSECURE, state->settings.allowInsecureTls ? BST_CHECKED : BST_UNCHECKED);
        SendDlgItemMessageW(
            hwnd,
            IDC_URL,
            EM_SETCUEBANNER,
            TRUE,
            reinterpret_cast<LPARAM>(L"http://100.x.x.x:8787/api/v1/stream.mjpeg"));
        SendDlgItemMessageW(hwnd, IDC_TOKEN, EM_SETCUEBANNER, TRUE, reinterpret_cast<LPARAM>(L"카메라 폰에 표시된 토큰"));
        StartTailscale(state, hwnd, TailscaleAction::Status);
        return TRUE;
    }
    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case IDC_SHOWTOKEN: {
            bool show = IsDlgButtonChecked(hwnd, IDC_SHOWTOKEN) == BST_CHECKED;
            SendDlgItemMessageW(hwnd, IDC_TOKEN, EM_SETPASSWORDCHAR, show ? 0 : static_cast<WPARAM>(L'*'), 0);
            InvalidateRect(GetDlgItem(hwnd, IDC_TOKEN), nullptr, TRUE);
            return TRUE;
        }
        case IDC_TEST:
            StartTest(state, hwnd);
            return TRUE;
        case IDC_TS_UP:
            StartTailscale(state, hwnd, TailscaleAction::Connect);
            return TRUE;
        case IDC_TS_DOWN:
            StartTailscale(state, hwnd, TailscaleAction::Disconnect);
            return TRUE;
        case IDC_TS_HELP:
            ShowTailscaleGuide(hwnd);
            return TRUE;
        case IDOK: {
            Settings settings = ReadDialogSettings(hwnd);
            if (!settings.url.empty() && !StartsWithHttp(settings.url)) {
                MessageBoxW(hwnd, L"주소는 http:// 또는 https:// 로 시작해야 합니다.", L"원격 카메라", MB_ICONWARNING);
                return TRUE;
            }
            if (!SaveSettings(settings)) {
                MessageBoxW(hwnd, L"설정을 저장하지 못했습니다.", L"원격 카메라", MB_ICONERROR);
                return TRUE;
            }
            CloseDialog(state, hwnd, IDOK);
            return TRUE;
        }
        case IDCANCEL:
            CloseDialog(state, hwnd, IDCANCEL);
            return TRUE;
        default:
            break;
        }
        break;
    case WM_APP_TEST: {
        auto* text = reinterpret_cast<std::wstring*>(lParam);
        if (state && !state->closing && text) {
            SetDlgItemTextW(hwnd, IDC_STATUS, text->c_str());
        }
        delete text;
        if (state && state->thread) {
            CloseHandle(state->thread);
            state->thread = nullptr;
        }
        EnableWindow(GetDlgItem(hwnd, IDC_TEST), TRUE);
        return TRUE;
    }
    case WM_APP_TAILSCALE: {
        auto* text = reinterpret_cast<std::wstring*>(lParam);
        if (state && !state->closing && text) {
            SetDlgItemTextW(hwnd, IDC_TS_STATUS, text->c_str());
        }
        delete text;
        if (state && state->tailscaleThread) {
            CloseHandle(state->tailscaleThread);
            state->tailscaleThread = nullptr;
        }
        if (!state || !state->closing) {
            SetTailscaleBusy(hwnd, false);
        }
        return TRUE;
    }
    case WM_CLOSE:
        CloseDialog(state, hwnd, IDCANCEL);
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

}  // namespace

Settings LoadSettings() {
    Settings settings;
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, kKeyPath, 0, KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) {
        return settings;
    }
    ReadStringValue(key, L"Url", settings.url);

    DWORD tokenSize = 0;
    if (RegGetValueW(key, nullptr, L"Token", RRF_RT_REG_BINARY, nullptr, nullptr, &tokenSize) == ERROR_SUCCESS && tokenSize > 0) {
        std::vector<unsigned char> blob(tokenSize);
        if (RegGetValueW(key, nullptr, L"Token", RRF_RT_REG_BINARY, nullptr, blob.data(), &tokenSize) == ERROR_SUCCESS) {
            DATA_BLOB input{};
            input.pbData = blob.data();
            input.cbData = tokenSize;
            DATA_BLOB output{};
            if (CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) {
                if (output.cbData >= sizeof(wchar_t)) {
                    settings.token.assign(
                        reinterpret_cast<wchar_t*>(output.pbData),
                        output.cbData / sizeof(wchar_t));
                    while (!settings.token.empty() && settings.token.back() == L'\0') {
                        settings.token.pop_back();
                    }
                }
                LocalFree(output.pbData);
            }
        }
    }

    DWORD fill = 0;
    DWORD insecure = 0;
    if (ReadDwordValue(key, L"Fill", fill)) {
        settings.fill = fill != 0;
    }
    if (ReadDwordValue(key, L"InsecureTls", insecure)) {
        settings.allowInsecureTls = insecure != 0;
    }
    RegCloseKey(key);
    return settings;
}

bool SaveSettings(const Settings& settings) {
    HKEY key = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, kKeyPath, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
        return false;
    }
    std::wstring url = settings.url;
    LONG urlResult = RegSetValueExW(
        key,
        L"Url",
        0,
        REG_SZ,
        reinterpret_cast<const BYTE*>(url.c_str()),
        static_cast<DWORD>((url.size() + 1) * sizeof(wchar_t)));

    LONG tokenResult = ERROR_SUCCESS;
    std::wstring token = settings.token;
    if (token.empty()) {
        RegDeleteValueW(key, L"Token");
    } else {
        DATA_BLOB input{};
        input.pbData = reinterpret_cast<BYTE*>(token.data());
        input.cbData = static_cast<DWORD>(token.size() * sizeof(wchar_t));
        DATA_BLOB output{};
        if (!CryptProtectData(&input, L"RemoteCamSaver", nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) {
            RegCloseKey(key);
            return false;
        }
        tokenResult = RegSetValueExW(key, L"Token", 0, REG_BINARY, output.pbData, output.cbData);
        LocalFree(output.pbData);
    }

    DWORD fill = settings.fill ? 1 : 0;
    DWORD insecure = settings.allowInsecureTls ? 1 : 0;
    LONG fillResult = RegSetValueExW(key, L"Fill", 0, REG_DWORD, reinterpret_cast<const BYTE*>(&fill), sizeof(fill));
    LONG insecureResult = RegSetValueExW(key, L"InsecureTls", 0, REG_DWORD, reinterpret_cast<const BYTE*>(&insecure), sizeof(insecure));
    RegCloseKey(key);
    return urlResult == ERROR_SUCCESS && tokenResult == ERROR_SUCCESS && fillResult == ERROR_SUCCESS && insecureResult == ERROR_SUCCESS;
}

void RunSettingsDialog(HINSTANCE instance, HWND parent) {
    INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_STANDARD_CLASSES};
    InitCommonControlsEx(&controls);

    DialogState state;
    state.settings = LoadSettings();
    std::vector<unsigned char> templateBytes = BuildSettingsTemplate();
    INT_PTR result = DialogBoxIndirectParamW(
        instance,
        reinterpret_cast<LPCDLGTEMPLATEW>(templateBytes.data()),
        parent,
        SettingsProc,
        reinterpret_cast<LPARAM>(&state));
    if (result == -1) {
        wchar_t text[96];
        swprintf_s(text, L"설정 창을 열지 못했습니다. (%lu)", GetLastError());
        MessageBoxW(parent, text, L"원격 카메라", MB_ICONERROR);
    }
}
