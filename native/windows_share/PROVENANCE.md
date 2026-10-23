# Windows track sharing

Original project code uses Windows `IDataTransferManagerInterop` for the owning
Godot HWND. The WinRT data callback provides frozen title, complete text and web
link. Only the receiving app handles recipient selection and sending.

The Godot wrapper reuses the existing cleared Godot C++ bindings and MinGW static
library. A separate runtime compiled with the already installed Visual C++ and
Windows SDK avoids introducing compiler ABI assumptions across C++ toolchains;
the boundary uses only C functions, UTF-16 pointers, booleans and an opaque state.
The wrapper loads the exact content-addressed runtime beside its own DLL, with no
working-directory/PATH lookup. Each adapter owns one manager and revokes the old
callback when replacing its payload or being destroyed. Text is bounded to 4096
UTF-16 units; the HWND must belong to the current process and thread.
The one small runtime remains mapped until process exit so delayed WinRT delegate
releases cannot call into unloaded code; per-adapter event/data ownership is still
released normally.

Build through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1
-Action BuildWindowsShare`. No SDK/package download is needed. Keep the existing
compiler/binding notices plus `game/platform/windows/SHARE-NOTICE.txt` with future
Windows packages. The current Android export excludes the Windows directory.

API references: [Microsoft's desktop sharing interop](https://learn.microsoft.com/en-us/windows/apps/develop/ui/display-ui-objects#for-classes-that-implement-idatatransfermanagerinterop)
and [Godot native window handles](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-window-get-native-handle).
Actual commands, DLL fingerprints, verification scope and remaining acceptance
are in [the task receipt](../../docs/TRACK_DIRECT_SHARE_2026_10_22.md).
