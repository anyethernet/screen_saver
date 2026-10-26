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

// 100.64.0.2 만 넣어도 기본 포트와 영상 경로를 붙인다.
// 이미 포트나 전체 주소가 있으면 그 값을 유지한다.
inline std::wstring NormalizeStreamUrl(std::wstring input) {
    input = TrimCopy(input);
    if (input.empty()) {
        return input;
    }
    std::wstring scheme = L"http://";
    std::wstring rest = input;
    if (StartsWithHttp(input)) {
        const auto schemeEnd = input.find(L"://");
        scheme = input.substr(0, schemeEnd + 3);
        rest = input.substr(schemeEnd + 3);
    }
    std::wstring authority = rest;
    std::wstring path;
    const auto slash = rest.find(L'/');
    if (slash != std::wstring::npos) {
        authority = rest.substr(0, slash);
        path = rest.substr(slash);
    }
    bool hasPort = false;
    if (!authority.empty() && authority.front() == L'[') {
        const auto end = authority.find(L']');
        hasPort = end != std::wstring::npos && end + 1 < authority.size() && authority[end + 1] == L':';
    } else {
        hasPort = authority.find(L':') != std::wstring::npos;
    }
    if (!hasPort && !authority.empty()) {
        authority += L":8787";
    }
    if (path.empty() || path == L"/") {
        path = L"/api/v1/stream.mjpeg";
    }
    return scheme + authority + path;
}

// 기본 포트와 기본 경로이면 설정 칸에는 IP만 보여 준다.
inline std::wstring DisplayAddress(const std::wstring& stored) {
    const std::wstring full = NormalizeStreamUrl(stored);
    const std::wstring prefix = L"http://";
    const std::wstring suffix = L":8787/api/v1/stream.mjpeg";
    if (full.size() > prefix.size() + suffix.size() && full.rfind(prefix, 0) == 0 &&
        full.compare(full.size() - suffix.size(), suffix.size(), suffix) == 0) {
        return full.substr(prefix.size(), full.size() - prefix.size() - suffix.size());
    }
    return full;
}
