#include "tailscale.h"

#include <string>
#include <vector>

#pragma comment(lib, "advapi32.lib")

namespace {

struct CommandResult {
    bool started = false;
    bool timedOut = false;
    DWORD exitCode = 1;
    std::string output;
};

std::string ToLowerAscii(std::string text) {
    for (char& ch : text) {
        if (ch >= 'A' && ch <= 'Z') {
            ch = static_cast<char>(ch - 'A' + 'a');
        }
    }
    return text;
}

std::wstring ReadRegistryString(HKEY root, const wchar_t* keyPath, const wchar_t* valueName) {
    DWORD size = 0;
    if (RegGetValueW(root, keyPath, valueName, RRF_RT_REG_SZ, nullptr, nullptr, &size) != ERROR_SUCCESS || size < sizeof(wchar_t)) {
        return L"";
    }
    std::wstring text(size / sizeof(wchar_t), L'\0');
    if (RegGetValueW(root, keyPath, valueName, RRF_RT_REG_SZ, nullptr, text.data(), &size) != ERROR_SUCCESS) {
        return L"";
    }
    while (!text.empty() && text.back() == L'\0') {
        text.pop_back();
    }
    return text;
}

bool FileExists(const std::wstring& path) {
    if (path.empty()) {
        return false;
    }
    DWORD attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

std::wstring FindTailscaleExe() {
    wchar_t programFiles[MAX_PATH]{};
    DWORD length = GetEnvironmentVariableW(L"ProgramFiles", programFiles, MAX_PATH);
    if (length > 0 && length < MAX_PATH) {
        std::wstring path = std::wstring(programFiles) + L"\\Tailscale\\tailscale.exe";
        if (FileExists(path)) {
            return path;
        }
    }

    const wchar_t* registryKeys[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\tailscale.exe",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Tailscale IPN",
    };
    for (const wchar_t* key : registryKeys) {
        std::wstring path = ReadRegistryString(HKEY_LOCAL_MACHINE, key, nullptr);
        if (path.empty()) {
            path = ReadRegistryString(HKEY_LOCAL_MACHINE, key, L"InstallLocation");
        }
        if (!path.empty() && path.find(L"tailscale.exe") == std::wstring::npos) {
            if (path.back() != L'\\') {
                path.push_back(L'\\');
            }
            path += L"tailscale.exe";
        }
        if (FileExists(path)) {
            return path;
        }
    }

    wchar_t found[MAX_PATH]{};
    if (SearchPathW(nullptr, L"tailscale.exe", nullptr, MAX_PATH, found, nullptr) > 0 && FileExists(found)) {
        return found;
    }
    return L"";
}

bool StopRequested(const TailscaleCancel* cancel) {
    return cancel && cancel->stop && cancel->stop->load();
}

void PublishProcess(TailscaleCancel* cancel, HANDLE process) {
    if (!cancel || !cancel->lock || !cancel->process) {
        return;
    }
    EnterCriticalSection(cancel->lock);
    *cancel->process = process;
    LeaveCriticalSection(cancel->lock);
}

void UnpublishProcess(TailscaleCancel* cancel, HANDLE process) {
    if (cancel && cancel->lock && cancel->process) {
        EnterCriticalSection(cancel->lock);
        if (*cancel->process == process) {
            *cancel->process = nullptr;
        }
        LeaveCriticalSection(cancel->lock);
    }
    if (process) {
        CloseHandle(process);
    }
}

void AppendOutput(std::string& output, const char* data, DWORD size) {
    constexpr size_t kMaxOutput = 64 * 1024;
    if (output.size() >= kMaxOutput || size == 0) {
        return;
    }
    size_t room = kMaxOutput - output.size();
    if (size > room) {
        size = static_cast<DWORD>(room);
    }
    output.append(data, size);
}

void DrainPipe(HANDLE pipe, std::string& output) {
    for (;;) {
        DWORD available = 0;
        if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr) || available == 0) {
            return;
        }
        char buffer[2048];
        DWORD chunk = available > sizeof(buffer) ? sizeof(buffer) : available;
        DWORD read = 0;
        if (!ReadFile(pipe, buffer, chunk, &read, nullptr) || read == 0) {
            return;
        }
        AppendOutput(output, buffer, read);
    }
}

CommandResult RunCaptured(const std::wstring& exe, const std::wstring& args, DWORD timeoutMs, TailscaleCancel* cancel) {
    CommandResult result;
    if (StopRequested(cancel)) {
        result.timedOut = true;
        return result;
    }

    std::wstring command = L"\"" + exe + L"\"";
    if (!args.empty()) {
        command.push_back(L' ');
        command += args;
    }
    std::vector<wchar_t> commandBuffer(command.begin(), command.end());
    commandBuffer.push_back(L'\0');

    SECURITY_ATTRIBUTES inherited{sizeof(inherited), nullptr, TRUE};
    HANDLE readPipe = nullptr;
    HANDLE writePipe = nullptr;
    if (!CreatePipe(&readPipe, &writePipe, &inherited, 0)) {
        return result;
    }
    SetHandleInformation(readPipe, HANDLE_FLAG_INHERIT, 0);
    HANDLE input = CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, &inherited, OPEN_EXISTING, 0, nullptr);

    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    startup.wShowWindow = SW_HIDE;
    startup.hStdInput = input;
    startup.hStdOutput = writePipe;
    startup.hStdError = writePipe;

    PROCESS_INFORMATION process{};
    BOOL created = CreateProcessW(
        exe.c_str(),
        commandBuffer.data(),
        nullptr,
        nullptr,
        TRUE,
        CREATE_NO_WINDOW,
        nullptr,
        nullptr,
        &startup,
        &process);
    CloseHandle(writePipe);
    if (input) {
        CloseHandle(input);
    }
    if (!created) {
        CloseHandle(readPipe);
        return result;
    }
    CloseHandle(process.hThread);
    result.started = true;
    PublishProcess(cancel, process.hProcess);

    DWORD startedAt = GetTickCount();
    for (;;) {
        DrainPipe(readPipe, result.output);
        if (StopRequested(cancel)) {
            TerminateProcess(process.hProcess, 1);
            result.timedOut = true;
            WaitForSingleObject(process.hProcess, 2000);
            break;
        }
        DWORD wait = WaitForSingleObject(process.hProcess, 50);
        if (wait == WAIT_OBJECT_0) {
            break;
        }
        if (GetTickCount() - startedAt > timeoutMs) {
            TerminateProcess(process.hProcess, 1);
            result.timedOut = true;
            WaitForSingleObject(process.hProcess, 2000);
            break;
        }
    }
    DrainPipe(readPipe, result.output);
    DWORD exitCode = 1;
    GetExitCodeProcess(process.hProcess, &exitCode);
    result.exitCode = exitCode;
    UnpublishProcess(cancel, process.hProcess);
    CloseHandle(readPipe);
    return result;
}

std::string ExtractJsonString(const std::string& json, const char* key) {
    std::string pattern = std::string("\"") + key + "\"";
    size_t pos = json.find(pattern);
    if (pos == std::string::npos) {
        return {};
    }
    pos = json.find(':', pos + pattern.size());
    if (pos == std::string::npos) {
        return {};
    }
    pos = json.find('"', pos + 1);
    if (pos == std::string::npos) {
        return {};
    }
    size_t end = json.find('"', pos + 1);
    if (end == std::string::npos || end <= pos + 1) {
        return {};
    }
    return json.substr(pos + 1, end - pos - 1);
}

TailscaleState MapBackendState(const std::string& state) {
    std::string lower = ToLowerAscii(state);
    if (lower == "running") {
        return TailscaleState::Running;
    }
    if (lower == "stopped") {
        return TailscaleState::Stopped;
    }
    if (lower == "needslogin") {
        return TailscaleState::NeedsLogin;
    }
    if (lower == "needsmachineauth") {
        return TailscaleState::NeedsMachineAuth;
    }
    if (lower == "starting") {
        return TailscaleState::Starting;
    }
    return TailscaleState::Failed;
}

TailscaleState ParseTailscaleOutput(const std::string& output) {
    std::string state = ExtractJsonString(output, "BackendState");
    if (!state.empty()) {
        return MapBackendState(state);
    }
    std::string lower = ToLowerAscii(output);
    if (lower.find("stopped") != std::string::npos) {
        return TailscaleState::Stopped;
    }
    if (lower.find("needs login") != std::string::npos || lower.find("logged out") != std::string::npos) {
        return TailscaleState::NeedsLogin;
    }
    if (lower.find("running") != std::string::npos) {
        return TailscaleState::Running;
    }
    return TailscaleState::Failed;
}

std::wstring LabelForState(TailscaleState state) {
    switch (state) {
    case TailscaleState::Missing:
        return L"Tailscale: 설치되지 않음";
    case TailscaleState::Running:
        return L"Tailscale: 연결됨";
    case TailscaleState::Stopped:
        return L"Tailscale: 연결 끊김";
    case TailscaleState::NeedsLogin:
        return L"Tailscale: 로그인 필요";
    case TailscaleState::NeedsMachineAuth:
        return L"Tailscale: 기기 승인 필요";
    case TailscaleState::Starting:
        return L"Tailscale: 연결하는 중";
    case TailscaleState::Failed:
        return L"Tailscale: 상태를 확인하지 못했습니다";
    }
    return L"Tailscale: 상태를 확인하지 못했습니다";
}

bool UnknownTimeoutFlag(const std::string& output) {
    std::string lower = ToLowerAscii(output);
    return lower.find("unknown") != std::string::npos && lower.find("timeout") != std::string::npos;
}

std::wstring QueryStatus(const std::wstring& exe, TailscaleCancel* cancel) {
    CommandResult status = RunCaptured(exe, L"status --json", 10000, cancel);
    if (StopRequested(cancel)) {
        return L"Tailscale: 확인이 취소되었습니다";
    }
    if (!status.started || status.timedOut) {
        return L"Tailscale: 상태를 확인하지 못했습니다";
    }
    TailscaleState state = ParseTailscaleOutput(status.output);
    if (state == TailscaleState::Failed) {
        CommandResult plain = RunCaptured(exe, L"status", 10000, cancel);
        if (!plain.output.empty()) {
            state = ParseTailscaleOutput(plain.output);
        }
    }
    return LabelForState(state);
}

}  // namespace

std::wstring PerformTailscaleAction(TailscaleAction action, TailscaleCancel* cancel) {
    std::wstring exe = FindTailscaleExe();
    if (exe.empty()) {
        return L"Tailscale: 설치되지 않음";
    }
    if (action == TailscaleAction::Connect) {
        CommandResult up = RunCaptured(exe, L"up --timeout=20s", 25000, cancel);
        if (StopRequested(cancel)) {
            return L"Tailscale: 확인이 취소되었습니다";
        }
        if (!up.started) {
            return L"Tailscale: 연결을 시작하지 못했습니다";
        }
        if (up.timedOut) {
            return L"Tailscale: 연결 시간이 초과되었습니다";
        }
        if (up.exitCode != 0 && UnknownTimeoutFlag(up.output)) {
            up = RunCaptured(exe, L"up", 25000, cancel);
            if (StopRequested(cancel)) {
                return L"Tailscale: 확인이 취소되었습니다";
            }
            if (up.timedOut) {
                return L"Tailscale: 연결 시간이 초과되었습니다";
            }
        }
        std::wstring status = QueryStatus(exe, cancel);
        TailscaleState state = TailscaleState::Failed;
        if (status == LabelForState(TailscaleState::Running)) {
            state = TailscaleState::Running;
        } else if (status == LabelForState(TailscaleState::NeedsLogin)) {
            state = TailscaleState::NeedsLogin;
        } else if (status == LabelForState(TailscaleState::NeedsMachineAuth)) {
            state = TailscaleState::NeedsMachineAuth;
        } else if (status == LabelForState(TailscaleState::Stopped)) {
            state = TailscaleState::Stopped;
        }
        if (state == TailscaleState::Running || state == TailscaleState::NeedsLogin || state == TailscaleState::NeedsMachineAuth) {
            return status;
        }
        if (up.exitCode != 0) {
            return L"Tailscale: 연결하지 못했습니다";
        }
        return status;
    }
    if (action == TailscaleAction::Disconnect) {
        CommandResult down = RunCaptured(exe, L"down", 15000, cancel);
        if (StopRequested(cancel)) {
            return L"Tailscale: 확인이 취소되었습니다";
        }
        if (!down.started || down.timedOut) {
            return L"Tailscale: 연결을 끊지 못했습니다";
        }
        std::wstring status = QueryStatus(exe, cancel);
        if (status == LabelForState(TailscaleState::Running)) {
            return L"Tailscale: 연결을 끊지 못했습니다";
        }
        if (down.exitCode != 0 && status == LabelForState(TailscaleState::Failed)) {
            return L"Tailscale: 연결을 끊지 못했습니다";
        }
        return status == LabelForState(TailscaleState::Failed) ? L"Tailscale: 연결 끊김" : status;
    }
    return QueryStatus(exe, cancel);
}

std::wstring RunTailscaleSelfTest() {
    if (ParseTailscaleOutput("{\"BackendState\":\"Running\"}") != TailscaleState::Running) {
        return L"parse running";
    }
    if (ParseTailscaleOutput("{\"BackendState\": \"Stopped\"}") != TailscaleState::Stopped) {
        return L"parse stopped";
    }
    if (ParseTailscaleOutput("{\"BackendState\":\"NeedsLogin\"}") != TailscaleState::NeedsLogin) {
        return L"parse login";
    }
    if (ParseTailscaleOutput("Tailscale is stopped.\n") != TailscaleState::Stopped) {
        return L"parse text";
    }
    if (ParseTailscaleOutput("") != TailscaleState::Failed) {
        return L"parse empty";
    }

    wchar_t systemDir[MAX_PATH]{};
    if (GetSystemDirectoryW(systemDir, MAX_PATH) == 0) {
        return L"system directory";
    }
    std::wstring cmd = std::wstring(systemDir) + L"\\cmd.exe";
    CommandResult exitCode = RunCaptured(cmd, L"/d /c exit 3", 5000, nullptr);
    if (!exitCode.started || exitCode.exitCode != 3) {
        return L"process exit";
    }
    CommandResult echo = RunCaptured(cmd, L"/d /c echo hello-tailscale", 5000, nullptr);
    if (!echo.started || echo.output.find("hello-tailscale") == std::string::npos) {
        return L"process output";
    }
    FindTailscaleExe();
    return L"";
}
