#pragma once

#include <string>

inline std::wstring TrimCopy(std::wstring text) {
    auto space = [](wchar_t ch) {
        return ch == L' ' || ch == L'\t' || ch == L'\r' || ch == L'\n';
    };
    while (!text.empty() && space(text.front())) {
        text.erase(text.begin());
    }
    while (!text.empty() && space(text.back())) {
        text.pop_back();
    }
    if (text.size() >= 2 &&
        ((text.front() == L'"' && text.back() == L'"') ||
         (text.front() == L'\'' && text.back() == L'\''))) {
        text = text.substr(1, text.size() - 2);
        text = TrimCopy(text);
    }
    return text;
}

inline bool StartsWithHttp(const std::wstring& url) {
    return url.rfind(L"http://", 0) == 0 || url.rfind(L"https://", 0) == 0;
}
