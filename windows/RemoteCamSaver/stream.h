#pragma once

#include "win.h"

#include <atomic>
#include <functional>
#include <string>
#include <vector>
#include <winhttp.h>

// 화면 보호기가 집 카메라에 요청하는 영상.
//
// GET {설정에 넣은 주소}
// Authorization: Bearer {토큰}     토큰이 비어 있으면 이 헤더는 보내지 않는다.
//
// HTTP 200
// Content-Type: multipart/x-mixed-replace; boundary=frame
// Cache-Control: no-store
//
// --frame
// Content-Type: image/jpeg
// Content-Length: <바이트 수>
//
// <JPEG 바이트>
//
// 프레임은 반복된다. 권장은 약 5fps, 가로 960px 전후.
// 20초 안에 다음 데이터가 없으면 연결이 끊긴 것으로 보고 다시 접속한다.
// Tailscale 주소와 공유기 포트포워딩 주소 모두 같은 요청이다.

struct StreamConfig {
    std::wstring url;
    std::wstring token;
    bool allowInsecureTls = false;
};

// 진행 중인 WinHTTP 요청을 다른 스레드에서 끊어 화면 보호기가 바로 끝나게 한다.
struct RequestSlot {
    CRITICAL_SECTION lock;
    HINTERNET handle = nullptr;

    RequestSlot();
    ~RequestSlot();

    RequestSlot(const RequestSlot&) = delete;
    RequestSlot& operator=(const RequestSlot&) = delete;

    void Publish(HINTERNET request);
    void Close();
};

// 한 번의 연결을 끝까지 읽는다. stop 이 되면 빈 문자열을 반환한다.
// 그 외에는 화면에 보여줄 한국어 오류를 반환한다.
std::wstring RunMjpegStream(
    const StreamConfig& config,
    std::atomic<bool>& stop,
    RequestSlot& slot,
    const std::function<void(const std::vector<unsigned char>&)>& onFrame);

// 첫 JPEG 한 장을 받아 크기를 확인한다. 성공하면 빈 문자열.
std::wstring TestMjpegStream(
    const StreamConfig& config,
    std::atomic<bool>& stop,
    RequestSlot& slot,
    int& width,
    int& height);

HBITMAP CreateBitmapFromJpeg(const unsigned char* data, size_t size, int& width, int& height);

// 실패하면 영어 진단 문자열, 성공하면 빈 문자열.
std::wstring RunParserSelfTest();
