#pragma once

#include "win.h"

#include <atomic>
#include <string>

// Tailscale 연결/해제는 tailscale.exe 의 up / down 이다.
// 화면 보호기 설정에서 이 명령을 직접 실행한다.

enum class TailscaleAction {
    Status,
    Connect,
    Disconnect,
};

enum class TailscaleState {
    Missing,
    Running,
    Stopped,
    NeedsLogin,
    NeedsMachineAuth,
    Starting,
    Failed,
};

struct TailscaleCancel {
    CRITICAL_SECTION* lock = nullptr;
    HANDLE* process = nullptr;
    std::atomic<bool>* stop = nullptr;
};

std::wstring PerformTailscaleAction(TailscaleAction action, TailscaleCancel* cancel);
std::wstring RunTailscaleSelfTest();
