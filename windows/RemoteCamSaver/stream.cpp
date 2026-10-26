#include "stream.h"

#include "util.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>

namespace Gdiplus {
using std::max;
using std::min;
}
#include <gdiplus.h>
#include <objidl.h>

#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "ole32.lib")

namespace {

constexpr size_t kMaxFrameBytes = 8 * 1024 * 1024;
constexpr size_t kMaxHeaderBytes = 64 * 1024;

std::string ToLowerAscii(std::string text) {
    for (char& ch : text) {
        ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
    }
    return text;
}

std::string WideToUtf8(const std::wstring& text) {
    if (text.empty()) {
        return {};
    }
    int count = WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
    if (count <= 0) {
        return {};
    }
    std::string utf8(static_cast<size_t>(count), '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), utf8.data(), count, nullptr, nullptr);
    return utf8;
}

size_t FindBytes(const std::vector<unsigned char>& buffer, size_t start, const std::string& needle) {
    if (needle.empty() || buffer.size() < start + needle.size()) {
        return std::string::npos;
    }
    auto begin = buffer.begin() + static_cast<std::ptrdiff_t>(start);
    auto found = std::search(begin, buffer.end(), needle.begin(), needle.end());
    if (found == buffer.end()) {
        return std::string::npos;
    }
    return static_cast<size_t>(found - buffer.begin());
}

std::string ExtractBoundary(const std::string& contentType) {
    std::string lower = ToLowerAscii(contentType);
    const std::string key = "boundary=";
    size_t pos = lower.find(key);
    if (pos == std::string::npos) {
        return {};
    }
    pos += key.size();
    if (pos < contentType.size() && contentType[pos] == '"') {
        size_t end = contentType.find('"', pos + 1);
        if (end == std::string::npos) {
            return {};
        }
        return contentType.substr(pos + 1, end - pos - 1);
    }
    size_t end = contentType.find(';', pos);
    std::string value = contentType.substr(pos, end == std::string::npos ? std::string::npos : end - pos);
    while (!value.empty() && (value.back() == ' ' || value.back() == '\t' || value.back() == '\r')) {
        value.pop_back();
    }
    while (!value.empty() && (value.front() == ' ' || value.front() == '\t')) {
        value.erase(value.begin());
    }
    return value;
}

int ParseContentLength(const std::string& headers) {
    std::string lower = ToLowerAscii(headers);
    const std::string key = "content-length:";
    size_t pos = lower.find(key);
    if (pos == std::string::npos) {
        return -1;
    }
    pos += key.size();
    while (pos < headers.size() && (headers[pos] == ' ' || headers[pos] == '\t')) {
        ++pos;
    }
    if (pos >= headers.size() || !std::isdigit(static_cast<unsigned char>(headers[pos]))) {
        return -1;
    }
    int value = 0;
    while (pos < headers.size() && std::isdigit(static_cast<unsigned char>(headers[pos]))) {
        int digit = headers[pos] - '0';
        if (value > (kMaxFrameBytes - static_cast<size_t>(digit)) / 10) {
            return -1;
        }
        value = value * 10 + digit;
        ++pos;
    }
    return value;
}

class MjpegAssembler {
public:
    bool SetContentType(const std::string& contentType) {
        std::string lower = ToLowerAscii(contentType);
        if (lower.find("multipart/") != std::string::npos) {
            std::string boundary = ExtractBoundary(contentType);
            if (boundary.empty()) {
                Fail(L"스트림 경계자를 찾지 못했습니다.");
                return false;
            }
            multipart_ = true;
            delimiter_ = "--" + boundary;
            return true;
        }
        if (lower.find("image/jpeg") != std::string::npos) {
            multipart_ = false;
            return true;
        }
        Fail(L"영상 스트림이 아닙니다.");
        return false;
    }

    bool Push(const unsigned char* data, size_t size, std::vector<std::vector<unsigned char>>& frames) {
        if (failed_) {
            return false;
        }
        buffer_.insert(buffer_.end(), data, data + size);
        return Pull(frames);
    }

    bool Failed() const { return failed_; }
    bool Ended() const { return ended_; }
    const std::wstring& Error() const { return error_; }

private:
    void Fail(const wchar_t* message) {
        failed_ = true;
        error_ = message;
    }

    bool Pull(std::vector<std::vector<unsigned char>>& frames) {
        if (multipart_) {
            return PullMultipart(frames);
        }
        return PullRawJpeg(frames);
    }

    bool PullRawJpeg(std::vector<std::vector<unsigned char>>& frames) {
        for (;;) {
            size_t soi = std::string::npos;
            for (size_t i = 0; i + 1 < buffer_.size(); ++i) {
                if (buffer_[i] == 0xFF && buffer_[i + 1] == 0xD8) {
                    soi = i;
                    break;
                }
            }
            if (soi == std::string::npos) {
                if (buffer_.size() > 4) {
                    buffer_.erase(buffer_.begin(), buffer_.end() - 1);
                }
                return true;
            }
            if (soi > 0) {
                buffer_.erase(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(soi));
            }
            size_t eoi = std::string::npos;
            for (size_t i = 2; i + 1 < buffer_.size(); ++i) {
                if (buffer_[i] == 0xFF && buffer_[i + 1] == 0xD9) {
                    eoi = i;
                    break;
                }
            }
            if (eoi == std::string::npos) {
                if (buffer_.size() > kMaxFrameBytes) {
                    Fail(L"프레임이 너무 큽니다.");
                    return false;
                }
                return true;
            }
            frames.emplace_back(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(eoi + 2));
            buffer_.erase(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(eoi + 2));
        }
    }

    bool PullMultipart(std::vector<std::vector<unsigned char>>& frames) {
        for (;;) {
            if (!inPart_) {
                size_t pos = FindBytes(buffer_, 0, delimiter_);
                if (pos == std::string::npos) {
                    if (buffer_.size() > delimiter_.size() + 8) {
                        buffer_.erase(buffer_.begin(), buffer_.end() - static_cast<std::ptrdiff_t>(delimiter_.size() + 8));
                    }
                    if (buffer_.size() > kMaxHeaderBytes && delimiter_.empty()) {
                        Fail(L"스트림 형식을 해석하지 못했습니다.");
                        return false;
                    }
                    return true;
                }
                size_t after = pos + delimiter_.size();
                if (after + 1 < buffer_.size() && buffer_[after] == '-' && buffer_[after + 1] == '-') {
                    ended_ = true;
                    buffer_.clear();
                    return true;
                }
                size_t lineEnd = FindBytes(buffer_, after, "\r\n");
                if (lineEnd == std::string::npos) {
                    if (pos > 0) {
                        buffer_.erase(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(pos));
                    }
                    return true;
                }
                buffer_.erase(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(lineEnd + 2));
                inPart_ = true;
                headerDone_ = false;
                contentLength_ = -1;
            }

            if (!headerDone_) {
                size_t sep = FindBytes(buffer_, 0, "\r\n\r\n");
                if (sep == std::string::npos) {
                    if (buffer_.size() > kMaxHeaderBytes) {
                        Fail(L"스트림 헤더를 해석하지 못했습니다.");
                        return false;
                    }
                    return true;
                }
                std::string headers(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(sep));
                buffer_.erase(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(sep + 4));
                contentLength_ = ParseContentLength(headers);
                headerDone_ = true;
            }

            if (contentLength_ >= 0) {
                if (buffer_.size() < static_cast<size_t>(contentLength_)) {
                    if (buffer_.size() > kMaxFrameBytes) {
                        Fail(L"프레임이 너무 큽니다.");
                        return false;
                    }
                    return true;
                }
                frames.emplace_back(buffer_.begin(), buffer_.begin() + contentLength_);
                buffer_.erase(buffer_.begin(), buffer_.begin() + contentLength_);
                inPart_ = false;
                continue;
            }

            size_t pos = FindBytes(buffer_, 0, delimiter_);
            if (pos == std::string::npos) {
                if (buffer_.size() > kMaxFrameBytes) {
                    Fail(L"프레임이 너무 큽니다.");
                    return false;
                }
                return true;
            }
            size_t end = pos;
            if (end >= 2 && buffer_[end - 2] == '\r' && buffer_[end - 1] == '\n') {
                end -= 2;
            }
            frames.emplace_back(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(end));
            buffer_.erase(buffer_.begin(), buffer_.begin() + static_cast<std::ptrdiff_t>(pos));
            inPart_ = false;
        }
    }

    std::vector<unsigned char> buffer_;
    std::string delimiter_;
    bool multipart_ = false;
    bool inPart_ = false;
    bool headerDone_ = false;
    bool failed_ = false;
    bool ended_ = false;
    int contentLength_ = -1;
    std::wstring error_;
};

std::wstring FormatWinHttpError(DWORD error) {
    switch (error) {
    case ERROR_WINHTTP_CANNOT_CONNECT:
        return L"서버에 연결하지 못했습니다.";
    case ERROR_WINHTTP_TIMEOUT:
        return L"연결 시간이 초과되었습니다.";
    case ERROR_WINHTTP_NAME_NOT_RESOLVED:
        return L"주소를 찾지 못했습니다.";
    case ERROR_WINHTTP_SECURE_FAILURE:
    case ERROR_WINHTTP_SECURE_CERT_CN_INVALID:
    case ERROR_WINHTTP_SECURE_CERT_DATE_INVALID:
    case ERROR_WINHTTP_SECURE_INVALID_CA:
        return L"HTTPS 인증서를 확인하지 못했습니다. 자체 서명 인증서라면 설정에서 허용하세요.";
    case ERROR_WINHTTP_CONNECTION_ERROR:
        return L"연결이 끊어졌습니다.";
    default: {
        wchar_t text[64];
        swprintf_s(text, L"연결 오류 (%lu)", error);
        return text;
    }
    }
}

std::wstring HttpStatusMessage(DWORD status) {
    if (status == 401 || status == 403) {
        return L"인증에 실패했습니다. 토큰을 확인하세요.";
    }
    if (status == 404) {
        return L"영상 주소를 찾지 못했습니다.";
    }
    wchar_t text[64];
    swprintf_s(text, L"서버가 %lu 응답을 보냈습니다.", status);
    return text;
}

struct UrlParts {
    std::wstring host;
    std::wstring path;
    INTERNET_PORT port = 0;
    bool https = false;
};

bool Crack(const std::wstring& url, UrlParts& parts, std::wstring& error) {
    URL_COMPONENTS components{};
    components.dwStructSize = sizeof(components);
    wchar_t host[256]{};
    wchar_t path[4096]{};
    wchar_t extra[2048]{};
    components.lpszHostName = host;
    components.dwHostNameLength = _countof(host);
    components.lpszUrlPath = path;
    components.dwUrlPathLength = _countof(path);
    components.lpszExtraInfo = extra;
    components.dwExtraInfoLength = _countof(extra);
    if (!WinHttpCrackUrl(url.c_str(), static_cast<DWORD>(url.size()), 0, &components)) {
        error = L"주소 형식이 올바르지 않습니다.";
        return false;
    }
    if (components.nScheme != INTERNET_SCHEME_HTTP && components.nScheme != INTERNET_SCHEME_HTTPS) {
        error = L"주소는 http:// 또는 https:// 로 시작해야 합니다.";
        return false;
    }
    parts.host = host;
    parts.path = std::wstring(path) + extra;
    if (parts.path.empty()) {
        parts.path = L"/";
    }
    parts.port = components.nPort;
    parts.https = components.nScheme == INTERNET_SCHEME_HTTPS;
    return true;
}

void EnsureCom() {
    thread_local bool started = false;
    if (!started) {
        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        started = true;
    }
}

}  // namespace

RequestSlot::RequestSlot() {
    InitializeCriticalSection(&lock);
}

RequestSlot::~RequestSlot() {
    Close();
    DeleteCriticalSection(&lock);
}

void RequestSlot::Publish(HINTERNET request) {
    EnterCriticalSection(&lock);
    handle = request;
    LeaveCriticalSection(&lock);
}

void RequestSlot::Close() {
    EnterCriticalSection(&lock);
    if (handle) {
        WinHttpCloseHandle(handle);
        handle = nullptr;
    }
    LeaveCriticalSection(&lock);
}

std::wstring RunMjpegStream(
    const StreamConfig& config,
    std::atomic<bool>& stop,
    RequestSlot& slot,
    const std::function<void(const std::vector<unsigned char>&)>& onFrame) {
    if (stop) {
        return L"";
    }
    std::wstring url = NormalizeStreamUrl(config.url);
    if (url.empty()) {
        return L"카메라 IP가 없습니다.";
    }

    UrlParts parts;
    std::wstring error;
    if (!Crack(url, parts, error)) {
        return error;
    }

    HINTERNET session = WinHttpOpen(
        L"RemoteCamSaver/1.0",
        WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
        WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS,
        0);
    if (!session) {
        return FormatWinHttpError(GetLastError());
    }
    WinHttpSetTimeouts(session, 8000, 8000, 10000, 20000);

    HINTERNET connect = WinHttpConnect(session, parts.host.c_str(), parts.port, 0);
    if (!connect) {
        DWORD winError = GetLastError();
        WinHttpCloseHandle(session);
        return FormatWinHttpError(winError);
    }

    DWORD flags = parts.https ? WINHTTP_FLAG_SECURE : 0;
    HINTERNET request = WinHttpOpenRequest(
        connect,
        L"GET",
        parts.path.c_str(),
        nullptr,
        WINHTTP_NO_REFERER,
        WINHTTP_DEFAULT_ACCEPT_TYPES,
        flags);
    if (!request) {
        DWORD winError = GetLastError();
        WinHttpCloseHandle(connect);
        WinHttpCloseHandle(session);
        return FormatWinHttpError(winError);
    }

    slot.Publish(request);
    if (stop) {
        slot.Close();
        WinHttpCloseHandle(connect);
        WinHttpCloseHandle(session);
        return L"";
    }

    if (parts.https && config.allowInsecureTls) {
        DWORD security = SECURITY_FLAG_IGNORE_UNKNOWN_CA | SECURITY_FLAG_IGNORE_CERT_DATE_INVALID |
                         SECURITY_FLAG_IGNORE_CERT_CN_INVALID | SECURITY_FLAG_IGNORE_CERT_WRONG_USAGE;
        WinHttpSetOption(request, WINHTTP_OPTION_SECURITY_FLAGS, &security, sizeof(security));
    }

    std::wstring token = TrimCopy(config.token);
    if (!token.empty()) {
        std::wstring header = L"Authorization: Bearer " + token + L"\r\n";
        WinHttpAddRequestHeaders(request, header.c_str(), static_cast<DWORD>(-1), WINHTTP_ADDREQ_FLAG_ADD | WINHTTP_ADDREQ_FLAG_REPLACE);
    }
    WinHttpAddRequestHeaders(
        request,
        L"Accept: multipart/x-mixed-replace, image/jpeg\r\nCache-Control: no-cache\r\n",
        static_cast<DWORD>(-1),
        WINHTTP_ADDREQ_FLAG_ADD);

    if (!WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) ||
        !WinHttpReceiveResponse(request, nullptr)) {
        DWORD winError = GetLastError();
        slot.Close();
        WinHttpCloseHandle(connect);
        WinHttpCloseHandle(session);
        if (stop) {
            return L"";
        }
        return FormatWinHttpError(winError);
    }

    DWORD status = 0;
    DWORD statusSize = sizeof(status);
    WinHttpQueryHeaders(
        request,
        WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
        WINHTTP_HEADER_NAME_BY_INDEX,
        &status,
        &statusSize,
        WINHTTP_NO_HEADER_INDEX);
    if (status != 200) {
        slot.Close();
        WinHttpCloseHandle(connect);
        WinHttpCloseHandle(session);
        return HttpStatusMessage(status);
    }

    wchar_t contentType[512]{};
    DWORD contentTypeSize = sizeof(contentType);
    if (!WinHttpQueryHeaders(
            request,
            WINHTTP_QUERY_CONTENT_TYPE,
            WINHTTP_HEADER_NAME_BY_INDEX,
            contentType,
            &contentTypeSize,
            WINHTTP_NO_HEADER_INDEX)) {
        contentType[0] = L'\0';
    }

    MjpegAssembler assembler;
    if (!assembler.SetContentType(WideToUtf8(contentType))) {
        std::wstring formatError = assembler.Error();
        if (!contentType[0]) {
            formatError += L" 응답 형식이 비어 있습니다.";
        } else {
            formatError += L" (" + std::wstring(contentType) + L")";
        }
        slot.Close();
        WinHttpCloseHandle(connect);
        WinHttpCloseHandle(session);
        return formatError;
    }

    bool gotFrame = false;
    std::vector<unsigned char> chunk(16 * 1024);
    while (!stop && !assembler.Ended() && !assembler.Failed()) {
        DWORD read = 0;
        if (!WinHttpReadData(request, chunk.data(), static_cast<DWORD>(chunk.size()), &read)) {
            DWORD winError = GetLastError();
            slot.Close();
            WinHttpCloseHandle(connect);
            WinHttpCloseHandle(session);
            if (stop) {
                return L"";
            }
            if (gotFrame && (winError == ERROR_WINHTTP_CONNECTION_ERROR || winError == ERROR_WINHTTP_TIMEOUT)) {
                return L"연결이 끊어졌습니다.";
            }
            return FormatWinHttpError(winError);
        }
        if (read == 0) {
            break;
        }
        std::vector<std::vector<unsigned char>> frames;
        if (!assembler.Push(chunk.data(), read, frames)) {
            error = assembler.Error();
            break;
        }
        for (const auto& frame : frames) {
            if (frame.size() >= 2 && frame[0] == 0xFF && frame[1] == 0xD8) {
                gotFrame = true;
                onFrame(frame);
            }
        }
    }

    slot.Close();
    WinHttpCloseHandle(connect);
    WinHttpCloseHandle(session);
    if (stop) {
        return L"";
    }
    if (assembler.Failed()) {
        return assembler.Error().empty() ? L"스트림을 해석하지 못했습니다." : assembler.Error();
    }
    if (!gotFrame) {
        return L"영상 프레임을 받지 못했습니다.";
    }
    return L"연결이 끊어졌습니다.";
}

HBITMAP CreateBitmapFromJpeg(const unsigned char* data, size_t size, int& width, int& height) {
    width = 0;
    height = 0;
    if (!data || size < 4 || data[0] != 0xFF || data[1] != 0xD8) {
        return nullptr;
    }
    EnsureCom();
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, size);
    if (!memory) {
        return nullptr;
    }
    void* locked = GlobalLock(memory);
    if (!locked) {
        GlobalFree(memory);
        return nullptr;
    }
    memcpy(locked, data, size);
    GlobalUnlock(memory);

    IStream* stream = nullptr;
    if (FAILED(CreateStreamOnHGlobal(memory, TRUE, &stream))) {
        GlobalFree(memory);
        return nullptr;
    }
    Gdiplus::Bitmap bitmap(stream);
    HBITMAP result = nullptr;
    if (bitmap.GetLastStatus() == Gdiplus::Ok) {
        width = static_cast<int>(bitmap.GetWidth());
        height = static_cast<int>(bitmap.GetHeight());
        if (bitmap.GetHBITMAP(Gdiplus::Color(255, 0, 0, 0), &result) != Gdiplus::Ok) {
            result = nullptr;
            width = 0;
            height = 0;
        }
    }
    stream->Release();
    return result;
}

std::wstring TestMjpegStream(
    const StreamConfig& config,
    std::atomic<bool>& stop,
    RequestSlot& slot,
    int& width,
    int& height) {
    width = 0;
    height = 0;
    bool decoded = false;
    std::wstring decodeError;
    auto error = RunMjpegStream(config, stop, slot, [&](const std::vector<unsigned char>& frame) {
        if (decoded || stop) {
            return;
        }
        HBITMAP bitmap = CreateBitmapFromJpeg(frame.data(), frame.size(), width, height);
        if (bitmap && width > 0 && height > 0) {
            DeleteObject(bitmap);
            decoded = true;
        } else {
            decodeError = L"영상을 해석하지 못했습니다.";
        }
        stop = true;
        slot.Close();
    });
    if (decoded) {
        return L"";
    }
    if (!decodeError.empty()) {
        return decodeError;
    }
    return error.empty() ? L"연결에 실패했습니다." : error;
}

std::wstring RunParserSelfTest() {
    if (NormalizeStreamUrl(L"100.64.0.2") != L"http://100.64.0.2:8787/api/v1/stream.mjpeg") {
        return L"bare ip was not expanded";
    }
    if (NormalizeStreamUrl(L"100.64.0.2:9000") != L"http://100.64.0.2:9000/api/v1/stream.mjpeg") {
        return L"explicit port was not kept";
    }
    if (NormalizeStreamUrl(L"http://100.64.0.2:8787/api/v1/stream.mjpeg") !=
        L"http://100.64.0.2:8787/api/v1/stream.mjpeg") {
        return L"full url was rewritten";
    }
    if (DisplayAddress(L"http://100.64.0.2:8787/api/v1/stream.mjpeg") != L"100.64.0.2") {
        return L"saved url was not shown as an ip";
    }

    auto expect = [](bool condition, const wchar_t* message) -> std::wstring {
        return condition ? L"" : message;
    };

    const unsigned char first[] = {0xFF, 0xD8, 0x00, 0x11, 0xFF, 0xD9};
    const unsigned char second[] = {0xFF, 0xD8, 0x22, 0x33, 0xFF, 0xD9};
    std::string body = "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\n\r\n";
    body.append(reinterpret_cast<const char*>(first), sizeof(first));
    body += "\r\n--frame\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\n\r\n";
    body.append(reinterpret_cast<const char*>(second), sizeof(second));
    body += "\r\n--frame--\r\n";

    MjpegAssembler assembler;
    if (!assembler.SetContentType("multipart/x-mixed-replace; boundary=frame")) {
        return L"content type was rejected";
    }
    std::vector<std::vector<unsigned char>> frames;
    for (size_t offset = 0; offset < body.size();) {
        size_t step = std::min<size_t>(3, body.size() - offset);
        if (!assembler.Push(reinterpret_cast<const unsigned char*>(body.data() + offset), step, frames)) {
            return L"multipart push failed";
        }
        offset += step;
    }
    if (auto error = expect(frames.size() == 2, L"expected two content-length frames"); !error.empty()) {
        return error;
    }
    if (frames[0].size() != sizeof(first) || frames[1].size() != sizeof(second) ||
        !std::equal(frames[0].begin(), frames[0].end(), first) ||
        !std::equal(frames[1].begin(), frames[1].end(), second)) {
        return L"frame bytes did not match";
    }
    if (!assembler.Ended()) {
        return L"closing boundary was not detected";
    }

    std::string quoted = "\r\n--myboundary\r\nContent-Type: image/jpeg\r\n\r\n";
    quoted.append(reinterpret_cast<const char*>(first), sizeof(first));
    quoted += "\r\n--myboundary\r\nContent-Type: image/jpeg\r\n\r\n";
    quoted.append(reinterpret_cast<const char*>(second), sizeof(second));
    quoted += "\r\n--myboundary--";
    MjpegAssembler unlengthed;
    if (!unlengthed.SetContentType("multipart/x-mixed-replace; boundary=\"myboundary\"")) {
        return L"quoted boundary was rejected";
    }
    frames.clear();
    if (!unlengthed.Push(reinterpret_cast<const unsigned char*>(quoted.data()), quoted.size(), frames)) {
        return L"boundary-only push failed";
    }
    if (frames.size() != 2 || !std::equal(frames[0].begin(), frames[0].end(), first)) {
        return L"boundary-only frames did not match";
    }

    std::string raw;
    raw.append(reinterpret_cast<const char*>(first), sizeof(first));
    raw.append(reinterpret_cast<const char*>(second), sizeof(second));
    MjpegAssembler rawAssembler;
    if (!rawAssembler.SetContentType("image/jpeg")) {
        return L"raw jpeg type was rejected";
    }
    frames.clear();
    if (!rawAssembler.Push(reinterpret_cast<const unsigned char*>(raw.data()), 1, frames) ||
        !rawAssembler.Push(reinterpret_cast<const unsigned char*>(raw.data() + 1), raw.size() - 1, frames)) {
        return L"raw jpeg push failed";
    }
    if (frames.size() != 2) {
        return L"raw jpeg frame count was wrong";
    }
    return L"";
}
