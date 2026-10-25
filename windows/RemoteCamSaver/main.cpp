#include "settings.h"
#include "stream.h"
#include "util.h"

#include <algorithm>
#include <cstdlib>
#include <commctrl.h>
#include <process.h>
#include <shellapi.h>
#include <string>
#include <vector>

namespace Gdiplus {
using std::max;
using std::min;
}
#include <gdiplus.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "ole32.lib")

namespace {

constexpr wchar_t kWindowClass[] = L"RemoteCamSaverWindow";
constexpr UINT kInputGraceMs = 700;
constexpr int kMouseSlop = 12;
constexpr DWORD kMinFrameIntervalMs = 80;

struct WindowData {
    HFONT font = nullptr;
    bool preview = false;
};

struct App {
    HINSTANCE instance = nullptr;
    bool preview = false;
    bool fill = false;
    std::wstring url;
    std::wstring token;
    bool insecure = false;
    std::atomic<bool> stop{false};
    bool stopping = false;
    CRITICAL_SECTION lock;
    std::vector<HWND> windows;
    HBITMAP frame = nullptr;
    int frameWidth = 0;
    int frameHeight = 0;
    std::wstring status;
    bool seenFrame = false;
    DWORD startTick = 0;
    bool haveAnchor = false;
    int anchorX = 0;
    int anchorY = 0;
    HANDLE thread = nullptr;
    RequestSlot slot;
    ULONG_PTR gdiplusToken = 0;

    App() { InitializeCriticalSection(&lock); }
    ~App() { DeleteCriticalSection(&lock); }
};

App* g_app = nullptr;

void SetStatus(const std::wstring& status) {
    std::vector<HWND> windows;
    EnterCriticalSection(&g_app->lock);
    g_app->status = status;
    windows = g_app->windows;
    LeaveCriticalSection(&g_app->lock);
    for (HWND hwnd : windows) {
        InvalidateRect(hwnd, nullptr, FALSE);
    }
}

void PublishFrame(HBITMAP bitmap, int width, int height) {
    HBITMAP previous = nullptr;
    std::vector<HWND> windows;
    EnterCriticalSection(&g_app->lock);
    previous = g_app->frame;
    g_app->frame = bitmap;
    g_app->frameWidth = width;
    g_app->frameHeight = height;
    g_app->status.clear();
    g_app->seenFrame = true;
    windows = g_app->windows;
    LeaveCriticalSection(&g_app->lock);
    if (previous) {
        DeleteObject(previous);
    }
    for (HWND hwnd : windows) {
        InvalidateRect(hwnd, nullptr, FALSE);
    }
}

void StopStream() {
    g_app->stop = true;
    g_app->slot.Close();
}

void JoinStream() {
    if (g_app->thread) {
        WaitForSingleObject(g_app->thread, 5000);
        CloseHandle(g_app->thread);
        g_app->thread = nullptr;
    }
}

void QuitScreensaver() {
    if (g_app->stopping) {
        return;
    }
    g_app->stopping = true;
    StopStream();
    std::vector<HWND> windows;
    EnterCriticalSection(&g_app->lock);
    windows = g_app->windows;
    LeaveCriticalSection(&g_app->lock);
    for (HWND hwnd : windows) {
        ShowWindow(hwnd, SW_HIDE);
    }
    PostQuitMessage(0);
}

unsigned __stdcall StreamThread(void*) {
    StreamConfig config;
    config.url = g_app->url;
    config.token = g_app->token;
    config.allowInsecureTls = g_app->insecure;
    int backoffMs = 1000;
    int badFrames = 0;
    DWORD lastFrameTick = 0;

    while (!g_app->stop) {
        SetStatus(g_app->seenFrame ? L"다시 연결하는 중…" : L"연결 중…");
        std::wstring error = RunMjpegStream(config, g_app->stop, g_app->slot, [&](const std::vector<unsigned char>& jpeg) {
            if (g_app->stop) {
                return;
            }
            DWORD now = GetTickCount();
            if (lastFrameTick != 0 && now - lastFrameTick < kMinFrameIntervalMs) {
                return;
            }
            int width = 0;
            int height = 0;
            HBITMAP bitmap = CreateBitmapFromJpeg(jpeg.data(), jpeg.size(), width, height);
            if (!bitmap) {
                ++badFrames;
                if (badFrames >= 5 && !g_app->seenFrame) {
                    SetStatus(L"영상을 해석하지 못했습니다.");
                }
                return;
            }
            badFrames = 0;
            lastFrameTick = now;
            PublishFrame(bitmap, width, height);
        });
        if (g_app->stop) {
            break;
        }
        if (!error.empty()) {
            SetStatus(error + L"\n다시 연결하는 중…");
        }
        for (int waited = 0; waited < backoffMs && !g_app->stop; waited += 100) {
            Sleep(100);
        }
        backoffMs = std::min(backoffMs * 2, 15000);
    }
    return 0;
}

RECT FitRect(int srcWidth, int srcHeight, const RECT& dest, bool fill) {
    RECT result = dest;
    if (srcWidth <= 0 || srcHeight <= 0) {
        return result;
    }
    int destWidth = dest.right - dest.left;
    int destHeight = dest.bottom - dest.top;
    double scaleX = static_cast<double>(destWidth) / srcWidth;
    double scaleY = static_cast<double>(destHeight) / srcHeight;
    double scale = fill ? std::max(scaleX, scaleY) : std::min(scaleX, scaleY);
    int width = static_cast<int>(srcWidth * scale);
    int height = static_cast<int>(srcHeight * scale);
    result.left = dest.left + (destWidth - width) / 2;
    result.top = dest.top + (destHeight - height) / 2;
    result.right = result.left + width;
    result.bottom = result.top + height;
    return result;
}

void PaintWindow(HWND hwnd) {
    PAINTSTRUCT paint;
    HDC dc = BeginPaint(hwnd, &paint);
    RECT client;
    GetClientRect(hwnd, &client);
    int width = client.right - client.left;
    int height = client.bottom - client.top;
    if (width <= 0 || height <= 0) {
        EndPaint(hwnd, &paint);
        return;
    }

    HDC memory = CreateCompatibleDC(dc);
    HBITMAP buffer = CreateCompatibleBitmap(dc, width, height);
    HBITMAP previousBuffer = static_cast<HBITMAP>(SelectObject(memory, buffer));
    HBRUSH black = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    FillRect(memory, &client, black);

    std::wstring status;
    EnterCriticalSection(&g_app->lock);
    HBITMAP frame = g_app->frame;
    int frameWidth = g_app->frameWidth;
    int frameHeight = g_app->frameHeight;
    status = g_app->status;
    bool fill = g_app->fill;
    if (frame) {
        HDC frameDc = CreateCompatibleDC(memory);
        HBITMAP previous = static_cast<HBITMAP>(SelectObject(frameDc, frame));
        RECT dest = FitRect(frameWidth, frameHeight, client, fill);
        SetStretchBltMode(memory, HALFTONE);
        SetBrushOrgEx(memory, 0, 0, nullptr);
        StretchBlt(
            memory,
            dest.left,
            dest.top,
            dest.right - dest.left,
            dest.bottom - dest.top,
            frameDc,
            0,
            0,
            frameWidth,
            frameHeight,
            SRCCOPY);
        SelectObject(frameDc, previous);
        DeleteDC(frameDc);
    }
    bool haveFrame = frame != nullptr;
    LeaveCriticalSection(&g_app->lock);

    if (!status.empty()) {
        auto* data = reinterpret_cast<WindowData*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        HFONT previousFont = data && data->font ? static_cast<HFONT>(SelectObject(memory, data->font)) : nullptr;
        SetBkMode(memory, TRANSPARENT);
        SetTextColor(memory, RGB(230, 230, 230));
        RECT text = client;
        if (haveFrame) {
            text.top = client.bottom - 72;
            DrawTextW(memory, status.c_str(), -1, &text, DT_CENTER | DT_WORDBREAK | DT_NOPREFIX);
        } else {
            text.top = height / 3;
            DrawTextW(memory, status.c_str(), -1, &text, DT_CENTER | DT_WORDBREAK | DT_NOPREFIX);
        }
        if (previousFont) {
            SelectObject(memory, previousFont);
        }
    }

    BitBlt(dc, 0, 0, width, height, memory, 0, 0, SRCCOPY);
    SelectObject(memory, previousBuffer);
    DeleteObject(buffer);
    DeleteDC(memory);
    EndPaint(hwnd, &paint);
}

bool InputIsArmed() {
    return GetTickCount() - g_app->startTick > kInputGraceMs;
}

LRESULT CALLBACK SaverProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    auto* data = reinterpret_cast<WindowData*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    switch (message) {
    case WM_CREATE: {
        auto* created = new WindowData();
        created->preview = g_app->preview;
        UINT dpi = GetDpiForWindow(hwnd);
        created->font = CreateFontW(
            -MulDiv(20, static_cast<int>(dpi), 72),
            0,
            0,
            0,
            FW_NORMAL,
            FALSE,
            FALSE,
            FALSE,
            DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS,
            CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY,
            DEFAULT_PITCH | FF_DONTCARE,
            L"Segoe UI");
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(created));
        if (created->preview) {
            SetTimer(hwnd, 1, 200, nullptr);
        }
        return 0;
    }
    case WM_TIMER: {
        if (data && data->preview) {
            HWND parent = GetParent(hwnd);
            if (parent) {
                RECT parentClient;
                GetClientRect(parent, &parentClient);
                MoveWindow(hwnd, 0, 0, parentClient.right, parentClient.bottom, FALSE);
            }
        }
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT:
        PaintWindow(hwnd);
        return 0;
    case WM_SETCURSOR:
        if (!g_app->preview) {
            SetCursor(nullptr);
            return TRUE;
        }
        break;
    case WM_MOUSEMOVE:
        if (!g_app->preview && InputIsArmed()) {
            int x = static_cast<short>(LOWORD(lParam));
            int y = static_cast<short>(HIWORD(lParam));
            if (!g_app->haveAnchor) {
                g_app->haveAnchor = true;
                g_app->anchorX = x;
                g_app->anchorY = y;
            } else if (std::abs(x - g_app->anchorX) + std::abs(y - g_app->anchorY) > kMouseSlop) {
                QuitScreensaver();
            }
        }
        return 0;
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
    case WM_LBUTTONDOWN:
    case WM_RBUTTONDOWN:
    case WM_MBUTTONDOWN:
        if (!g_app->preview && InputIsArmed()) {
            QuitScreensaver();
        }
        return 0;
    case WM_DESTROY: {
        if (data) {
            if (data->font) {
                DeleteObject(data->font);
            }
            delete data;
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
        }
        EnterCriticalSection(&g_app->lock);
        g_app->windows.erase(std::remove(g_app->windows.begin(), g_app->windows.end(), hwnd), g_app->windows.end());
        bool lastWindow = g_app->windows.empty();
        LeaveCriticalSection(&g_app->lock);
        StopStream();
        if (lastWindow) {
            PostQuitMessage(0);
        }
        return 0;
    }
    default:
        break;
    }
    return DefWindowProcW(hwnd, message, wParam, lParam);
}

HWND CreateSaverWindow(HINSTANCE instance, HWND parent, const RECT& bounds, bool preview) {
    DWORD style = preview ? (WS_CHILD | WS_VISIBLE) : (WS_POPUP | WS_VISIBLE);
    DWORD exStyle = preview ? 0 : (WS_EX_TOPMOST | WS_EX_TOOLWINDOW);
    int x = preview ? 0 : bounds.left;
    int y = preview ? 0 : bounds.top;
    int width = bounds.right - bounds.left;
    int height = bounds.bottom - bounds.top;
    return CreateWindowExW(
        exStyle,
        kWindowClass,
        L"원격 카메라",
        style,
        x,
        y,
        width,
        height,
        parent,
        nullptr,
        instance,
        nullptr);
}

BOOL CALLBACK MonitorProc(HMONITOR, HDC, LPRECT rect, LPARAM) {
    HWND hwnd = CreateSaverWindow(g_app->instance, nullptr, *rect, false);
    if (hwnd) {
        EnterCriticalSection(&g_app->lock);
        g_app->windows.push_back(hwnd);
        LeaveCriticalSection(&g_app->lock);
    }
    return TRUE;
}

void RegisterSaverClass(HINSTANCE instance) {
    WNDCLASSEXW windowClass{};
    windowClass.cbSize = sizeof(windowClass);
    windowClass.lpfnWndProc = SaverProc;
    windowClass.hInstance = instance;
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    windowClass.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    windowClass.lpszClassName = kWindowClass;
    RegisterClassExW(&windowClass);
}

int RunScreensaver(HINSTANCE instance, bool preview, HWND parent) {
    g_app->instance = instance;
    g_app->preview = preview;
    g_app->startTick = GetTickCount();
    RegisterSaverClass(instance);

    Settings settings = LoadSettings();
    g_app->url = settings.url;
    g_app->token = settings.token;
    g_app->fill = settings.fill;
    g_app->insecure = settings.allowInsecureTls;

    if (preview) {
        RECT bounds{};
        GetClientRect(parent, &bounds);
        HWND hwnd = CreateSaverWindow(instance, parent, bounds, true);
        if (!hwnd) {
            return 0;
        }
        EnterCriticalSection(&g_app->lock);
        g_app->windows.push_back(hwnd);
        LeaveCriticalSection(&g_app->lock);
    } else {
        EnumDisplayMonitors(nullptr, nullptr, MonitorProc, 0);
        if (g_app->windows.empty()) {
            RECT bounds{0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)};
            HWND hwnd = CreateSaverWindow(instance, nullptr, bounds, false);
            if (hwnd) {
                g_app->windows.push_back(hwnd);
            }
        }
        SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED);
    }

    if (TrimCopy(g_app->url).empty()) {
        SetStatus(L"영상 주소가 없습니다.\n화면 보호기 설정에서 집 카메라 주소를 입력하세요.");
    } else {
        uintptr_t thread = _beginthreadex(nullptr, 0, StreamThread, nullptr, 0, nullptr);
        g_app->thread = reinterpret_cast<HANDLE>(thread);
    }

    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    StopStream();
    JoinStream();
    std::vector<HWND> leftover;
    EnterCriticalSection(&g_app->lock);
    leftover = g_app->windows;
    LeaveCriticalSection(&g_app->lock);
    for (HWND hwnd : leftover) {
        DestroyWindow(hwnd);
    }
    if (g_app->frame) {
        DeleteObject(g_app->frame);
        g_app->frame = nullptr;
    }
    if (!preview) {
        SetThreadExecutionState(ES_CONTINUOUS);
    }
    return 0;
}

HWND ParseHwnd(const wchar_t* text) {
    if (!text || !*text) {
        return nullptr;
    }
    wchar_t* end = nullptr;
    unsigned long long value = wcstoull(text, &end, 10);
    if (end == text) {
        value = wcstoull(text, &end, 0);
    }
    return reinterpret_cast<HWND>(static_cast<ULONG_PTR>(value));
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    Gdiplus::GdiplusStartupInput input;
    ULONG_PTR gdiplusToken = 0;
    if (Gdiplus::GdiplusStartup(&gdiplusToken, &input, nullptr) != Gdiplus::Ok) {
        MessageBoxW(nullptr, L"그래픽 기능을 시작하지 못했습니다.", L"원격 카메라", MB_ICONERROR);
        CoUninitialize();
        return 1;
    }

    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    enum class Mode { Config, Run, Preview };
    Mode mode = Mode::Config;
    HWND parent = nullptr;
    if (argv) {
        for (int i = 1; i < argc; ++i) {
            std::wstring arg = argv[i];
            if (arg.size() < 2 || (arg[0] != L'/' && arg[0] != L'-')) {
                continue;
            }
            wchar_t command = static_cast<wchar_t>(towlower(arg[1]));
            if (!(arg.size() == 2 || (arg.size() > 2 && arg[2] == L':'))) {
                continue;
            }
            std::wstring attached = arg.size() > 3 && arg[2] == L':' ? arg.substr(3) : L"";
            if (command == L's') {
                mode = Mode::Run;
            } else if (command == L'c') {
                mode = Mode::Config;
                if (attached.empty() && i + 1 < argc && argv[i + 1][0] != L'/' && argv[i + 1][0] != L'-') {
                    attached = argv[++i];
                }
                parent = ParseHwnd(attached.c_str());
            } else if (command == L'p') {
                mode = Mode::Preview;
                if (attached.empty() && i + 1 < argc) {
                    attached = argv[++i];
                }
                parent = ParseHwnd(attached.c_str());
            }
        }
        LocalFree(argv);
    }

    int result = 0;
    if (mode == Mode::Config) {
        RunSettingsDialog(instance, parent);
    } else if (mode == Mode::Preview && !parent) {
        result = 0;
    } else {
        HANDLE mutex = nullptr;
        if (mode == Mode::Run) {
            mutex = CreateMutexW(nullptr, TRUE, L"Local\\RemoteCamSaver.Run");
            if (GetLastError() == ERROR_ALREADY_EXISTS) {
                if (mutex) {
                    CloseHandle(mutex);
                }
                Gdiplus::GdiplusShutdown(gdiplusToken);
                CoUninitialize();
                return 0;
            }
        }
        App app;
        g_app = &app;
        result = RunScreensaver(instance, mode == Mode::Preview, parent);
        g_app = nullptr;
        if (mutex) {
            CloseHandle(mutex);
        }
    }

    Gdiplus::GdiplusShutdown(gdiplusToken);
    CoUninitialize();
    return result;
}
