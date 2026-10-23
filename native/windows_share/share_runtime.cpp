// Original Windows share-sheet bridge. Only the operating system handles recipients.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shobjidl_core.h>
#include <roapi.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.ApplicationModel.DataTransfer.h>
#include <string>
#include <atomic>
#include <memory>

using namespace winrt;
using namespace winrt::Windows::ApplicationModel::DataTransfer;

struct ShareState {
    DataTransferManager manager{nullptr};
    event_token requested{};
    bool subscribed = false;
    bool apartment = false;
    std::shared_ptr<std::atomic<int>> requests = std::make_shared<std::atomic<int>>(0);

    void clear() noexcept {
        if (subscribed) {
            try { manager.DataRequested(requested); } catch (...) {}
        }
        subscribed = false;
        manager = nullptr;
    }
    ~ShareState() { clear(); if (apartment) RoUninitialize(); }
};

extern "C" __declspec(dllexport) void *bmt_share_create() noexcept {
    try {
        auto state = new ShareState;
        HRESULT result = RoInitialize(RO_INIT_SINGLETHREADED);
        if (FAILED(result) && result != RPC_E_CHANGED_MODE) { delete state; return nullptr; }
        state->apartment = SUCCEEDED(result);
        return state;
    } catch (...) { return nullptr; }
}

extern "C" __declspec(dllexport) void bmt_share_destroy(void *value) noexcept {
    delete static_cast<ShareState *>(value);
}

extern "C" __declspec(dllexport) int bmt_share_requests(void *value) noexcept {
    return value ? static_cast<ShareState *>(value)->requests->load() : 0;
}

extern "C" __declspec(dllexport) bool bmt_share_text(
        void *value, HWND window, const wchar_t *text, const wchar_t *title, const wchar_t *url) noexcept {
    DWORD process = 0;
    DWORD thread = GetWindowThreadProcessId(window, &process);
    if (!value || !IsWindow(window) || process != GetCurrentProcessId() || thread != GetCurrentThreadId()
            || !text || !title || !url || !*text || !*title
            || wcslen(text) > 4096 || wcslen(title) > 256 || wcslen(url) > 2048) return false;
    auto &state = *static_cast<ShareState *>(value);
    try {
        state.clear();
        state.requests->store(0);
        auto interop = get_activation_factory<DataTransferManager, IDataTransferManagerInterop>();
        check_hresult(interop->GetForWindow(window, guid_of<DataTransferManager>(), put_abi(state.manager)));
        // Freeze this exact public track payload; never look up a newer selection in the callback.
        std::wstring payload(text), heading(title), link(url);
        auto requests = state.requests;
        state.requested = state.manager.DataRequested([payload, heading, link, requests](auto const &, DataRequestedEventArgs const &args) {
            try {
                auto data = args.Request().Data();
                data.Properties().Title(heading);
                data.SetText(payload);
                if (link.rfind(L"https://", 0) == 0 || link.rfind(L"http://", 0) == 0)
                    data.SetWebLink(winrt::Windows::Foundation::Uri(link));
                data.RequestedOperation(DataPackageOperation::Copy);
                requests->fetch_add(1);
            } catch (...) { args.Request().FailWithDisplayText(L"Couldn't prepare this track link. Try again."); }
        });
        state.subscribed = true;
        check_hresult(interop->ShowShareUIForWindow(window));
        return true;
    } catch (...) { state.clear(); return false; }
}
