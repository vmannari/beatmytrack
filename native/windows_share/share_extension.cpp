// Original Godot adapter; reuse the project's existing cleared Godot C++ bindings.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <string>
#include "runtime_name.hpp"

using namespace godot;

class BmtWindowsShare : public RefCounted {
    GDCLASS(BmtWindowsShare, RefCounted)
    using Create = void *(*)();
    using Destroy = void (*)(void *);
    using Share = bool (*)(void *, HWND, const wchar_t *, const wchar_t *, const wchar_t *);
    using Requests = int (*)(void *);
    HMODULE module = nullptr;
    void *state = nullptr;
    Destroy destroy = nullptr;
    Share share = nullptr;
    Requests requests = nullptr;

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("share_text", "window", "text", "title", "url"), &BmtWindowsShare::share_text);
        ClassDB::bind_method(D_METHOD("data_requests"), &BmtWindowsShare::data_requests);
    }
public:
    BmtWindowsShare() {
        HMODULE self = nullptr;
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                reinterpret_cast<LPCWSTR>(&_bind_methods), &self)) return;
        wchar_t path[32768];
        DWORD length = GetModuleFileNameW(self, path, 32768);
        if (!length || length >= 32768) return;
        std::wstring file(path, length);
        file = file.substr(0, file.find_last_of(L"\\/") + 1) + BMT_SHARE_RUNTIME;
        // Never search the working directory or PATH for the runtime DLL.
        module = LoadLibraryExW(file.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!module) return;
        auto create = reinterpret_cast<Create>(GetProcAddress(module, "bmt_share_create"));
        destroy = reinterpret_cast<Destroy>(GetProcAddress(module, "bmt_share_destroy"));
        share = reinterpret_cast<Share>(GetProcAddress(module, "bmt_share_text"));
        requests = reinterpret_cast<Requests>(GetProcAddress(module, "bmt_share_requests"));
        if (create && destroy && share) {
            // WinRT can finish releasing a delegate after its event is revoked.
            // Keep this one small runtime mapped until process exit, so a late
            // COM release can never enter code from an unloaded DLL.
            HMODULE pinned = nullptr;
            if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                    reinterpret_cast<LPCWSTR>(share), &pinned)) state = create();
        }
    }
    ~BmtWindowsShare() {
        if (state && destroy) destroy(state);
        if (module) FreeLibrary(module);
    }
    bool share_text(int64_t window, const String &text, const String &title, const String &url) {
        if (!state || !share || !window || text.is_empty() || text.length() > 4096
                || title.is_empty() || title.length() > 256 || url.length() > 2048) return false;
        auto body = text.utf16(), heading = title.utf16(), link = url.utf16();
        return share(state, reinterpret_cast<HWND>(window), reinterpret_cast<const wchar_t *>(body.get_data()),
                reinterpret_cast<const wchar_t *>(heading.get_data()), reinterpret_cast<const wchar_t *>(link.get_data()));
    }
    int data_requests() const { return state && requests ? requests(state) : 0; }
};

void initialize_share(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<BmtWindowsShare>();
}
void uninitialize_share(ModuleInitializationLevel) {}

extern "C" GDExtensionBool GDE_EXPORT bmt_windows_share_init(
        GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr library, GDExtensionInitialization *init) {
    GDExtensionBinding::InitObject object(get_proc, library, init);
    object.register_initializer(initialize_share);
    object.register_terminator(uninitialize_share);
    object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return object.init();
}
