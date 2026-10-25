#pragma once

#include "win.h"

#include <string>

struct Settings {
    std::wstring url;
    std::wstring token;
    bool fill = false;
    bool allowInsecureTls = false;
};

Settings LoadSettings();
bool SaveSettings(const Settings& settings);
void RunSettingsDialog(HINSTANCE instance, HWND parent);
