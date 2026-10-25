#include "stream.h"
#include "tailscale.h"

#include <algorithm>
#include <shellapi.h>
#include <stdio.h>

namespace Gdiplus {
using std::max;
using std::min;
}
#include <gdiplus.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "gdiplus.lib")

int wmain(int argc, wchar_t** argv) {
    std::wstring parserError = RunParserSelfTest();
    if (!parserError.empty()) {
        wprintf(L"PARSER FAIL %ls\n", parserError.c_str());
        return 1;
    }
    wprintf(L"PARSER OK\n");
    std::wstring tailscaleError = RunTailscaleSelfTest();
    if (!tailscaleError.empty()) {
        wprintf(L"TAILSCALE FAIL %ls\n", tailscaleError.c_str());
        return 1;
    }
    wprintf(L"TAILSCALE OK\n");
    if (argc < 2) {
        return 0;
    }

    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    Gdiplus::GdiplusStartupInput input;
    ULONG_PTR token = 0;
    if (Gdiplus::GdiplusStartup(&token, &input, nullptr) != Gdiplus::Ok) {
        wprintf(L"GDIPLUS FAIL\n");
        CoUninitialize();
        return 1;
    }

    StreamConfig config;
    config.url = argv[1];
    if (argc >= 3) {
        config.token = argv[2];
    }
    std::atomic<bool> stop{false};
    RequestSlot slot;
    int width = 0;
    int height = 0;
    std::wstring error = TestMjpegStream(config, stop, slot, width, height);
    if (!error.empty()) {
        wprintf(L"NETWORK FAIL %ls\n", error.c_str());
        Gdiplus::GdiplusShutdown(token);
        CoUninitialize();
        return 1;
    }
    wprintf(L"NETWORK OK %d %d\n", width, height);
    Gdiplus::GdiplusShutdown(token);
    CoUninitialize();
    return 0;
}
