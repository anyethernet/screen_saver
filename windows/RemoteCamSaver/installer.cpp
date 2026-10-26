#include <objbase.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <windows.h>

#include <cwchar>
#include <string>
#include <vector>

#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(lib, "user32.lib")

namespace {

constexpr wchar_t kScrName[] = L"RemoteCamSaver.scr";
constexpr wchar_t kSetupName[] = L"RemoteCamSaver-Setup.exe";
constexpr wchar_t kUninstallKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\RemoteCamSaver";
constexpr wchar_t kAppKey[] = L"Software\\RemoteCamSaver";
constexpr int IDC_STATUS = 1001;
constexpr int IDC_INSTALL = 1002;
constexpr int IDC_UNINSTALL = 1003;
constexpr int IDC_SETTINGS = 1004;
constexpr int IDC_MODE_SAVER = 1005;
constexpr int IDC_MODE_WALL = 1006;
constexpr int IDC_MODE_BOTH = 1007;

enum class InstallMode {
    Saver = 1,
    Wallpaper = 2,
    Both = 3,
};

InstallMode SelectedMode(HWND hwnd) {
    if (IsDlgButtonChecked(hwnd, IDC_MODE_WALL) == BST_CHECKED) {
        return InstallMode::Wallpaper;
    }
    if (IsDlgButtonChecked(hwnd, IDC_MODE_BOTH) == BST_CHECKED) {
        return InstallMode::Both;
    }
    return InstallMode::Saver;
}

bool UsesSaver(InstallMode mode) {
    return mode == InstallMode::Saver || mode == InstallMode::Both;
}

bool UsesWallpaper(InstallMode mode) {
    return mode == InstallMode::Wallpaper || mode == InstallMode::Both;
}

const wchar_t* InstallArgument(InstallMode mode) {
    switch (mode) {
    case InstallMode::Wallpaper:
        return L"/install:wallpaper";
    case InstallMode::Both:
        return L"/install:both";
    case InstallMode::Saver:
    default:
        return L"/install:saver";
    }
}

InstallMode ParseInstallMode(const std::wstring& argument) {
    if (argument == L"/install:wallpaper" || argument == L"/install wallpaper") {
        return InstallMode::Wallpaper;
    }
    if (argument == L"/install:both" || argument == L"/install both") {
        return InstallMode::Both;
    }
    return InstallMode::Saver;
}

void SaveInstallMode(InstallMode mode) {
    HKEY key = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, kAppKey, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
        return;
    }
    DWORD value = static_cast<DWORD>(mode);
    RegSetValueExW(key, L"InstallMode", 0, REG_DWORD, reinterpret_cast<const BYTE*>(&value), sizeof(value));
    RegCloseKey(key);
}

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
    const auto* bytes = reinterpret_cast<const unsigned char*>(text);
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
    short x,
    short y,
    short cx,
    short cy,
    WORD id,
    WORD klass,
    const wchar_t* title) {
    Align4(buffer);
    AddDword(buffer, style);
    AddDword(buffer, 0);
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

bool IsUserAdmin() {
    BOOL member = FALSE;
    SID_IDENTIFIER_AUTHORITY authority = SECURITY_NT_AUTHORITY;
    PSID sid = nullptr;
    if (!AllocateAndInitializeSid(
            &authority,
            2,
            SECURITY_BUILTIN_DOMAIN_RID,
            DOMAIN_ALIAS_RID_ADMINS,
            0,
            0,
            0,
            0,
            0,
            0,
            &sid)) {
        return false;
    }
    CheckTokenMembership(nullptr, sid, &member);
    FreeSid(sid);
    return member == TRUE;
}

std::wstring ExePath() {
    wchar_t path[MAX_PATH]{};
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    return path;
}

std::wstring SystemScrPath() {
    wchar_t directory[MAX_PATH]{};
    if (!GetSystemDirectoryW(directory, MAX_PATH)) {
        return L"";
    }
    return std::wstring(directory) + L"\\" + kScrName;
}

std::wstring InstallDir() {
    wchar_t programs[MAX_PATH]{};
    if (FAILED(SHGetFolderPathW(nullptr, CSIDL_PROGRAM_FILES, nullptr, SHGFP_TYPE_CURRENT, programs))) {
        return L"";
    }
    return std::wstring(programs) + L"\\RemoteCamSaver";
}

std::wstring ShortcutPath() {
    wchar_t programs[MAX_PATH]{};
    if (FAILED(SHGetFolderPathW(nullptr, CSIDL_COMMON_PROGRAMS, nullptr, SHGFP_TYPE_CURRENT, programs))) {
        return L"";
    }
    return std::wstring(programs) + L"\\Webcam Screen Saver";
}

bool ContainsSaverName(const wchar_t* value) {
    std::wstring text = value == nullptr ? L"" : value;
    for (wchar_t& ch : text) {
        ch = static_cast<wchar_t>(towlower(ch));
    }
    return text.find(L"remotecamsaver.scr") != std::wstring::npos;
}

bool LoadPayload(std::vector<unsigned char>& bytes, std::wstring& error) {
    HRSRC resource = FindResourceW(nullptr, MAKEINTRESOURCEW(101), RT_RCDATA);
    if (!resource) {
        error = L"설치 파일 안에 화면 보호기가 없습니다.";
        return false;
    }
    HGLOBAL loaded = LoadResource(nullptr, resource);
    DWORD size = SizeofResource(nullptr, resource);
    const auto* data = static_cast<const unsigned char*>(LockResource(loaded));
    if (!data || size < 2 || data[0] != 'M' || data[1] != 'Z') {
        error = L"설치 파일 안의 화면 보호기를 읽지 못했습니다.";
        return false;
    }
    bytes.assign(data, data + size);
    return true;
}

bool WriteAll(const std::wstring& path, const std::vector<unsigned char>& bytes, std::wstring& error) {
    HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        error = GetLastError() == ERROR_SHARING_VIOLATION
            ? L"화면 보호기가 켜져 있습니다. 마우스를 움직여 끈 다음 다시 설치하세요."
            : L"화면 보호기 파일을 복사하지 못했습니다.";
        return false;
    }
    DWORD written = 0;
    BOOL ok = WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()), &written, nullptr);
    CloseHandle(file);
    if (!ok || written != bytes.size()) {
        error = L"화면 보호기 파일을 끝까지 쓰지 못했습니다.";
        return false;
    }
    return true;
}

bool LaunchSettings(bool wait, std::wstring& error) {
    std::wstring scr = SystemScrPath();
    if (scr.empty() || GetFileAttributesW(scr.c_str()) == INVALID_FILE_ATTRIBUTES) {
        error = L"화면 보호기가 설치되어 있지 않습니다.";
        return false;
    }
    std::wstring command = L"\"" + scr + L"\" /c";
    std::vector<wchar_t> mutableCommand(command.begin(), command.end());
    mutableCommand.push_back(L'\0');
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(scr.c_str(), mutableCommand.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup, &process)) {
        error = L"주소 설정을 열지 못했습니다.";
        return false;
    }
    CloseHandle(process.hThread);
    if (wait) {
        WaitForSingleObject(process.hProcess, INFINITE);
    }
    CloseHandle(process.hProcess);
    return true;
}

void OpenSaverPanel() {
    ShellExecuteW(
        nullptr,
        L"open",
        L"rundll32.exe",
        L"shell32.dll,Control_RunDLL desk.cpl,@screensaver",
        nullptr,
        SW_SHOWNORMAL);
}

bool CreateShortcut(
    const std::wstring& setupPath,
    const wchar_t* fileName,
    const wchar_t* arguments,
    const wchar_t* description,
    std::wstring& error) {
    std::wstring folder = ShortcutPath();
    if (folder.empty()) {
        error = L"시작 메뉴 위치를 찾지 못했습니다.";
        return false;
    }
    CreateDirectoryW(folder.c_str(), nullptr);
    std::wstring linkPath = folder + L"\\" + fileName;
    IShellLinkW* link = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link));
    if (FAILED(hr)) {
        error = L"시작 메뉴 바로 가기를 만들지 못했습니다.";
        return false;
    }
    link->SetPath(setupPath.c_str());
    link->SetArguments(arguments);
    link->SetDescription(description);
    link->SetWorkingDirectory(InstallDir().c_str());
    IPersistFile* file = nullptr;
    hr = link->QueryInterface(IID_PPV_ARGS(&file));
    if (SUCCEEDED(hr)) {
        hr = file->Save(linkPath.c_str(), TRUE);
        file->Release();
    }
    link->Release();
    if (FAILED(hr)) {
        error = L"시작 메뉴 바로 가기를 저장하지 못했습니다.";
        return false;
    }
    return true;
}

bool CreateModeShortcuts(const std::wstring& setupPath, InstallMode mode, std::wstring& error) {
    if (!CreateShortcut(
            setupPath,
            L"Webcam & Screen Saver Settings.lnk",
            L"/settings",
            L"Webcam & Screen Saver address and token",
            error)) {
        return false;
    }
    if (UsesWallpaper(mode)) {
        if (!CreateShortcut(
                setupPath,
                L"Webcam & Screen Saver Desktop.lnk",
                L"/wallpaper",
                L"아이콘 뒤에서 집 카메라 영상을 켭니다",
                error)) {
            return false;
        }
        if (!CreateShortcut(
                setupPath,
                L"Webcam & Screen Saver Desktop Off.lnk",
                L"/wallpaper-stop",
                L"바탕화면 영상을 끕니다",
                error)) {
            return false;
        }
    }
    if (UsesSaver(mode)) {
        if (!CreateShortcut(
                setupPath,
                L"Webcam & Screen Saver.lnk",
                L"/screensaver",
                L"Windows 화면 보호기 목록을 엽니다",
                error)) {
            return false;
        }
    }
    return true;
}

bool LaunchScr(const wchar_t* argument, std::wstring& error) {
    std::wstring scr = SystemScrPath();
    if (scr.empty() || GetFileAttributesW(scr.c_str()) == INVALID_FILE_ATTRIBUTES) {
        error = L"먼저 프로그램을 설치하세요.";
        return false;
    }
    std::wstring command = L"\"" + scr + L"\" " + argument;
    std::vector<wchar_t> mutableCommand(command.begin(), command.end());
    mutableCommand.push_back(L'\0');
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(scr.c_str(), mutableCommand.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup, &process)) {
        error = L"프로그램을 시작하지 못했습니다.";
        return false;
    }
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return true;
}

bool WriteUninstallKey(const std::wstring& setupPath, DWORD sizeKb, std::wstring& error) {
    HKEY key = nullptr;
    if (RegCreateKeyExW(HKEY_LOCAL_MACHINE, kUninstallKey, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
        error = L"제거 정보를 기록하지 못했습니다.";
        return false;
    }
    auto setString = [&](const wchar_t* name, const std::wstring& value) {
        RegSetValueExW(
            key,
            name,
            0,
            REG_SZ,
            reinterpret_cast<const BYTE*>(value.c_str()),
            static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
    };
    setString(L"DisplayName", L"Webcam & Screen Saver");
    setString(L"DisplayVersion", L"1.0.0");
    setString(L"Publisher", L"Webcam & Screen Saver");
    setString(L"InstallLocation", InstallDir());
    setString(L"DisplayIcon", setupPath);
    std::wstring uninstall = L"\"" + setupPath + L"\" /uninstall";
    setString(L"UninstallString", uninstall);
    setString(L"QuietUninstallString", uninstall);
    DWORD no = 1;
    RegSetValueExW(key, L"NoModify", 0, REG_DWORD, reinterpret_cast<const BYTE*>(&no), sizeof(no));
    RegSetValueExW(key, L"NoRepair", 0, REG_DWORD, reinterpret_cast<const BYTE*>(&no), sizeof(no));
    RegSetValueExW(key, L"EstimatedSize", 0, REG_DWORD, reinterpret_cast<const BYTE*>(&sizeKb), sizeof(sizeKb));
    RegCloseKey(key);
    return true;
}

bool DoInstall(InstallMode mode, std::wstring& error) {
    std::vector<unsigned char> payload;
    if (!LoadPayload(payload, error)) {
        return false;
    }
    std::wstring scr = SystemScrPath();
    std::wstring dir = InstallDir();
    if (scr.empty() || dir.empty()) {
        error = L"설치 위치를 찾지 못했습니다.";
        return false;
    }
    if (!WriteAll(scr, payload, error)) {
        return false;
    }
    CreateDirectoryW(dir.c_str(), nullptr);
    std::wstring setupPath = dir + L"\\" + kSetupName;
    if (_wcsicmp(ExePath().c_str(), setupPath.c_str()) != 0) {
        if (!CopyFileW(ExePath().c_str(), setupPath.c_str(), FALSE)) {
            error = L"설치 프로그램을 프로그램 폴더에 복사하지 못했습니다.";
            return false;
        }
    }
    DWORD sizeKb = static_cast<DWORD>((payload.size() + 1023) / 1024);
    if (!WriteUninstallKey(setupPath, sizeKb, error)) {
        return false;
    }
    if (!CreateModeShortcuts(setupPath, mode, error)) {
        return false;
    }
    SaveInstallMode(mode);
    return true;
}

void ClearSaverValue(HKEY root) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(root, L"Control Panel\\Desktop", 0, KEY_QUERY_VALUE | KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
        return;
    }
    wchar_t value[1024]{};
    DWORD size = sizeof(value);
    DWORD type = 0;
    if (RegQueryValueExW(key, L"SCRNSAVE.EXE", nullptr, &type, reinterpret_cast<BYTE*>(value), &size) == ERROR_SUCCESS &&
        type == REG_SZ &&
        ContainsSaverName(value)) {
        RegDeleteValueW(key, L"SCRNSAVE.EXE");
    }
    RegCloseKey(key);
}

void ClearSaverForAllUsers() {
    ClearSaverValue(HKEY_CURRENT_USER);
    HKEY users = nullptr;
    if (RegOpenKeyExW(HKEY_USERS, nullptr, 0, KEY_ENUMERATE_SUB_KEYS, &users) != ERROR_SUCCESS) {
        return;
    }
    for (DWORD index = 0;; ++index) {
        wchar_t name[256]{};
        DWORD length = 256;
        if (RegEnumKeyExW(users, index, name, &length, nullptr, nullptr, nullptr, nullptr) != ERROR_SUCCESS) {
            break;
        }
        if (wcsstr(name, L"_Classes") != nullptr) {
            continue;
        }
        HKEY hive = nullptr;
        if (RegOpenKeyExW(users, name, 0, KEY_READ, &hive) == ERROR_SUCCESS) {
            ClearSaverValue(hive);
            RegCloseKey(hive);
        }
    }
    RegCloseKey(users);
}

void ScheduleDeleteDir(const std::wstring& dir) {
    std::wstring command = L"cmd.exe /c ping 127.0.0.1 -n 3 > nul & rmdir /s /q \"" + dir + L"\"";
    std::vector<wchar_t> mutableCommand(command.begin(), command.end());
    mutableCommand.push_back(L'\0');
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW;
    startup.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION process{};
    if (CreateProcessW(nullptr, mutableCommand.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
    }
}

bool DoUninstall(std::wstring& error) {
    std::wstring scr = SystemScrPath();
    if (!scr.empty()) {
        if (!DeleteFileW(scr.c_str()) && GetLastError() != ERROR_FILE_NOT_FOUND) {
            if (GetLastError() == ERROR_SHARING_VIOLATION) {
                error = L"화면 보호기가 켜져 있습니다. 마우스를 움직여 끈 다음 다시 제거하세요.";
            } else {
                error = L"화면 보호기 파일을 지우지 못했습니다.";
            }
            return false;
        }
    }
    ClearSaverForAllUsers();
    std::wstring folder = ShortcutPath();
    if (!folder.empty()) {
        DeleteFileW((folder + L"\\Webcam & Screen Saver Settings.lnk").c_str());
        DeleteFileW((folder + L"\\Webcam & Screen Saver Desktop.lnk").c_str());
        DeleteFileW((folder + L"\\Webcam & Screen Saver Desktop Off.lnk").c_str());
        DeleteFileW((folder + L"\\원격 카메라 바탕화면.lnk").c_str());
        DeleteFileW((folder + L"\\원격 카메라 바탕화면 끄기.lnk").c_str());
        DeleteFileW((folder + L"\\원격 카메라 설정.lnk").c_str());
        DeleteFileW((folder + L"\\Webcam & Screen Saver.lnk").c_str());
        RemoveDirectoryW(folder.c_str());
    }
    HWND wallpaper = FindWindowW(L"RemoteCamSaverWindow", L"Webcam & Screen Saver Background");
    if (wallpaper) {
        PostMessageW(wallpaper, WM_CLOSE, 0, 0);
    }
    RegDeleteKeyW(HKEY_LOCAL_MACHINE, kUninstallKey);
    std::wstring dir = InstallDir();
    std::wstring setupPath = dir + L"\\" + kSetupName;
    if (_wcsicmp(ExePath().c_str(), setupPath.c_str()) == 0) {
        ScheduleDeleteDir(dir);
    } else if (!dir.empty()) {
        DeleteFileW(setupPath.c_str());
        RemoveDirectoryW(dir.c_str());
    }
    return true;
}

int RelaunchElevated(const wchar_t* argument) {
    SHELLEXECUTEINFOW info{};
    info.cbSize = sizeof(info);
    info.fMask = SEE_MASK_NOCLOSEPROCESS;
    info.lpVerb = L"runas";
    info.lpFile = ExePath().c_str();
    info.lpParameters = argument;
    info.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&info)) {
        return 1;
    }
    WaitForSingleObject(info.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(info.hProcess, &code);
    CloseHandle(info.hProcess);
    return static_cast<int>(code);
}

int RunInstallFlow(InstallMode mode) {
    if (!IsUserAdmin()) {
        return RelaunchElevated(InstallArgument(mode));
    }
    HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    std::wstring error;
    bool ok = DoInstall(mode, error);
    if (SUCCEEDED(com)) {
        CoUninitialize();
    }
    if (!ok) {
        MessageBoxW(nullptr, error.c_str(), L"Webcam & Screen Saver", MB_ICONERROR | MB_OK);
        return 1;
    }
    std::wstring message = L"설치했습니다.\n\n확인을 누르면 카메라 IP와 토큰 설정이 열립니다.";
    if (UsesSaver(mode) && UsesWallpaper(mode)) {
        message += L"\n설정을 닫으면 화면 보호기 목록이 열리고, 바탕화면 영상도 시작할 수 있습니다.";
    } else if (UsesSaver(mode)) {
        message += L"\n설정을 닫으면 Windows 화면 보호기 목록이 열립니다. 거기서 Webcam & Screen Saver를 고르고 대기 시간을 정하세요.";
    } else {
        message += L"\n설정을 닫으면 바탕화면 뒤에서 영상을 켭니다. 시작 메뉴의 Webcam & Screen Saver Desktop으로도 다시 켤 수 있습니다.";
    }
    MessageBoxW(nullptr, message.c_str(), L"Webcam & Screen Saver", MB_ICONINFORMATION | MB_OK);
    std::wstring settingsError;
    LaunchSettings(true, settingsError);
    if (UsesSaver(mode)) {
        OpenSaverPanel();
    }
    if (UsesWallpaper(mode)) {
        std::wstring wallpaperError;
        if (!LaunchScr(L"/w", wallpaperError)) {
            MessageBoxW(nullptr, wallpaperError.c_str(), L"Webcam & Screen Saver", MB_ICONWARNING | MB_OK);
        }
    }
    return 0;
}

int RunWallpaperFlow(bool start) {
    std::wstring error;
    if (!LaunchScr(start ? L"/w" : L"/q", error)) {
        MessageBoxW(nullptr, error.c_str(), L"Webcam & Screen Saver", MB_ICONINFORMATION | MB_OK);
        return 1;
    }
    return 0;
}

int RunUninstallFlow() {
    if (!IsUserAdmin()) {
        return RelaunchElevated(L"/uninstall");
    }
    if (MessageBoxW(
            nullptr,
            L"Webcam & Screen Saver를 이 PC에서 제거할까요?",
            L"Webcam & Screen Saver",
            MB_ICONQUESTION | MB_YESNO) != IDYES) {
        return 1;
    }
    std::wstring error;
    if (!DoUninstall(error)) {
        MessageBoxW(nullptr, error.c_str(), L"Webcam & Screen Saver", MB_ICONERROR | MB_OK);
        return 1;
    }
    MessageBoxW(nullptr, L"제거했습니다.", L"Webcam & Screen Saver", MB_ICONINFORMATION | MB_OK);
    return 0;
}

int RunSettingsFlow() {
    std::wstring error;
    if (!LaunchSettings(false, error)) {
        MessageBoxW(nullptr, error.c_str(), L"Webcam & Screen Saver", MB_ICONINFORMATION | MB_OK);
        return 1;
    }
    return 0;
}

bool Installed() {
    std::wstring scr = SystemScrPath();
    return !scr.empty() && GetFileAttributesW(scr.c_str()) != INVALID_FILE_ATTRIBUTES;
}

int RunScreensaverPanelFlow() {
    if (!Installed()) {
        MessageBoxW(nullptr, L"먼저 프로그램을 설치하세요.", L"Webcam & Screen Saver", MB_ICONINFORMATION | MB_OK);
        return 1;
    }
    OpenSaverPanel();
    return 0;
}

void UpdateStatus(HWND hwnd) {
    SetDlgItemTextW(
        hwnd,
        IDC_STATUS,
        Installed() ? L"이 PC에 설치되어 있습니다." : L"아직 설치되지 않았습니다.");
}

std::vector<unsigned char> BuildTemplate() {
    constexpr DWORD kStyle = DS_SETFONT | DS_MODALFRAME | DS_CENTER | WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_VISIBLE;
    std::vector<unsigned char> buffer;
    AddDword(buffer, kStyle);
    AddDword(buffer, 0);
    AddWord(buffer, 0);
    AddShort(buffer, 0);
    AddShort(buffer, 0);
    AddShort(buffer, 340);
    AddShort(buffer, 188);
    AddWord(buffer, 0);
    AddWord(buffer, 0);
    AddString(buffer, L"Webcam & Screen Saver Setup");
    AddWord(buffer, 9);
    AddString(buffer, L"Malgun Gothic");

    int count = 0;
    constexpr DWORD kStatic = WS_CHILD | WS_VISIBLE | SS_LEFT | SS_NOPREFIX;
    constexpr DWORD kButton = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON;
    constexpr DWORD kRadio = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTORADIOBUTTON;
    constexpr DWORD kGroup = WS_CHILD | WS_VISIBLE | BS_GROUPBOX;
    constexpr WORD kButtonClass = 0x0080;
    constexpr WORD kStaticClass = 0x0082;
    AddItem(
        buffer,
        count,
        kStatic,
        12,
        8,
        316,
        28,
        0xFFFF,
        kStaticClass,
        L"집 폰에 나온 IP와 토큰은 설치 뒤에 설정합니다.\n아래에서 화면 보호기, 바탕화면 배경, 또는 둘 다를 고르세요.");
    AddItem(buffer, count, kGroup, 12, 40, 316, 72, 0xFFFF, kButtonClass, L"사용 방식");
    AddItem(buffer, count, kRadio | WS_GROUP, 24, 56, 292, 14, IDC_MODE_SAVER, kButtonClass, L"화면 보호기만");
    AddItem(buffer, count, kRadio, 24, 72, 292, 14, IDC_MODE_WALL, kButtonClass, L"바탕화면 배경만");
    AddItem(buffer, count, kRadio, 24, 88, 292, 14, IDC_MODE_BOTH, kButtonClass, L"화면 보호기와 바탕화면 둘 다");
    AddItem(buffer, count, kStatic, 12, 118, 316, 14, IDC_STATUS, kStaticClass, L"");
    AddItem(buffer, count, kButton | BS_DEFPUSHBUTTON, 12, 140, 70, 16, IDC_INSTALL, kButtonClass, L"설치");
    AddItem(buffer, count, kButton, 90, 140, 70, 16, IDC_UNINSTALL, kButtonClass, L"제거");
    AddItem(buffer, count, kButton, 168, 140, 78, 16, IDC_SETTINGS, kButtonClass, L"주소 설정");
    AddItem(buffer, count, kButton, 254, 140, 62, 16, IDCANCEL, kButtonClass, L"닫기");
    buffer[8] = static_cast<unsigned char>(count & 0xFF);
    buffer[9] = static_cast<unsigned char>((count >> 8) & 0xFF);
    return buffer;
}

INT_PTR CALLBACK DialogProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM) {
    switch (message) {
    case WM_INITDIALOG:
        CheckRadioButton(hwnd, IDC_MODE_SAVER, IDC_MODE_BOTH, IDC_MODE_BOTH);
        UpdateStatus(hwnd);
        return TRUE;
    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case IDC_INSTALL:
            RunInstallFlow(SelectedMode(hwnd));
            UpdateStatus(hwnd);
            return TRUE;
        case IDC_UNINSTALL:
            RunUninstallFlow();
            UpdateStatus(hwnd);
            return TRUE;
        case IDC_SETTINGS: {
            std::wstring error;
            if (!LaunchSettings(false, error)) {
                MessageBoxW(hwnd, error.c_str(), L"Webcam & Screen Saver", MB_ICONINFORMATION | MB_OK);
            }
            return TRUE;
        }
        case IDCANCEL:
            EndDialog(hwnd, 0);
            return TRUE;
        default:
            break;
        }
        break;
    case WM_CLOSE:
        EndDialog(hwnd, 0);
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    int argc = 0;
    wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    std::wstring argument = argc >= 2 ? argv[1] : L"";
    LocalFree(argv);
    if (argument.rfind(L"/install", 0) == 0) {
        return RunInstallFlow(ParseInstallMode(argument));
    }
    if (argument == L"/uninstall") {
        return RunUninstallFlow();
    }
    if (argument == L"/settings") {
        return RunSettingsFlow();
    }
    if (argument == L"/wallpaper") {
        return RunWallpaperFlow(true);
    }
    if (argument == L"/wallpaper-stop") {
        return RunWallpaperFlow(false);
    }
    if (argument == L"/screensaver") {
        return RunScreensaverPanelFlow();
    }
    auto buffer = BuildTemplate();
    DialogBoxIndirectParamW(instance, reinterpret_cast<DLGTEMPLATE*>(buffer.data()), nullptr, DialogProc, 0);
    return 0;
}

