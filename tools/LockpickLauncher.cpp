#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <commctrl.h>
#include <algorithm>
#include <filesystem>
#include <iterator>
#include <string_view>

namespace {
constexpr UINT Initialize = WM_APP + 0x411;
constexpr UINT Refit = WM_APP + 0x412;
constexpr wchar_t BackdropClass[] = L"LockpickLetterboxBackdrop";

struct Size { int width, height; };
struct WindowState {
    HWND game = nullptr;
    HWND backdrop = nullptr;
    LONG_PTR framedStyle = 0;
    Size framedClient{};
    bool fullscreen = false;
} state;

Size GetSize(RECT rect) {
    return {rect.right - rect.left, rect.bottom - rect.top};
}

Size FitAspect(Size bounds) {
    const int units = std::max(0, std::min(bounds.width / 4, bounds.height / 3));
    return {4 * units, 3 * units};
}

MONITORINFO Monitor(HWND window) {
    MONITORINFO info{};
    info.cbSize = sizeof(info);
    if (!GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &info)) info.cbSize = 0;
    return info;
}

Size Client(HWND window) {
    RECT rect{};
    return GetClientRect(window, &rect) ? GetSize(rect) : Size{};
}

bool Center(HWND window, HWND behind, RECT area, Size size, UINT flags) {
    const auto bounds = GetSize(area);
    return SetWindowPos(window, behind, area.left + (bounds.width - size.width) / 2,
                        area.top + (bounds.height - size.height) / 2,
                        size.width, size.height, flags) != FALSE;
}

void FitWindowed(HWND window, Size wanted) {
    const auto monitor = Monitor(window);
    if (!monitor.cbSize) return;
    RECT frame{};
    const auto style = static_cast<DWORD>(GetWindowLongPtrW(window, GWL_STYLE));
    const auto exStyle = static_cast<DWORD>(GetWindowLongPtrW(window, GWL_EXSTYLE));
    if (!AdjustWindowRectExForDpi(&frame, style, GetMenu(window) != nullptr,
                                  exStyle, GetDpiForWindow(window))) return;
    const auto chrome = GetSize(frame);
    const auto work = GetSize(monitor.rcWork);
    const auto fit = FitAspect({std::min(wanted.width, work.width - chrome.width),
                                std::min(wanted.height, work.height - chrome.height)});
    if (!fit.width) return;
    Center(window, nullptr, monitor.rcWork, {fit.width + chrome.width, fit.height + chrome.height},
           SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

HWND CreateBackdrop() {
    const HINSTANCE instance = GetModuleHandleW(nullptr);
    WNDCLASSW type{};
    type.lpfnWndProc = DefWindowProcW;
    type.hInstance = instance;
    type.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
    type.lpszClassName = BackdropClass;
    if (!RegisterClassW(&type) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return nullptr;
    return CreateWindowExW(WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW, BackdropClass, L"",
                           WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, instance, nullptr);
}

void SyncBackdrop() {
    if (!state.backdrop) return;
    constexpr UINT zOrderOnly = SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE;
    if (!state.fullscreen || GetForegroundWindow() != state.game) {
        ShowWindow(state.backdrop, SW_HIDE);
        SetWindowPos(state.game, HWND_NOTOPMOST, 0, 0, 0, 0, zOrderOnly);
        return;
    }
    const auto monitor = Monitor(state.game);
    if (monitor.cbSize) {
        Center(state.backdrop, HWND_TOPMOST, monitor.rcMonitor, GetSize(monitor.rcMonitor),
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
        SetWindowPos(state.game, HWND_TOPMOST, 0, 0, 0, 0, zOrderOnly);
    }
}

bool FitFullscreen() {
    const auto monitor = Monitor(state.game);
    if (!monitor.cbSize) return false;
    const auto fit = FitAspect(GetSize(monitor.rcMonitor));
    return fit.width && Center(state.game, nullptr, monitor.rcMonitor, fit,
                               SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

void LeaveFullscreen() {
    state.fullscreen = false;
    SyncBackdrop();
    SetWindowLongPtrW(state.game, GWL_STYLE, state.framedStyle);
    FitWindowed(state.game, state.framedClient);
}

void ToggleFullscreen() {
    if (state.fullscreen) {
        LeaveFullscreen();
        return;
    }
    if (!state.backdrop) state.backdrop = CreateBackdrop();
    if (!state.backdrop) return;
    if (IsZoomed(state.game) || IsIconic(state.game)) ShowWindow(state.game, SW_RESTORE);
    state.framedStyle = GetWindowLongPtrW(state.game, GWL_STYLE);
    state.framedClient = Client(state.game);
    SetWindowLongPtrW(state.game, GWL_STYLE,
                      (state.framedStyle & ~static_cast<LONG_PTR>(WS_OVERLAPPEDWINDOW)) | WS_POPUP);
    state.fullscreen = true;
    if (!FitFullscreen()) LeaveFullscreen();
    SyncBackdrop();
}

bool FullscreenKey(UINT message, WPARAM key, LPARAM flags) {
    if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && key == VK_F11) return true;
    return message == WM_SYSKEYDOWN && key == VK_RETURN && (flags & (1L << 29));
}

LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM key, LPARAM flags,
                            UINT_PTR subclass, DWORD_PTR) {
    if (FullscreenKey(message, key, flags)) {
        if (!(flags & (1L << 30))) ToggleFullscreen();
        return 0;
    }
    switch (message) {
    case WM_SYSCOMMAND:
        if ((key & 0xfff0) == SC_MAXIMIZE) {
            ToggleFullscreen();
            return 0;
        }
        break;
    case Initialize:
        FitWindowed(window, Client(window));
        return 0;
    case Refit:
        if (state.fullscreen) {
            FitFullscreen();
            SyncBackdrop();
        }
        return 0;
    case WM_ACTIVATE:
        if (state.fullscreen) PostMessageW(window, Refit, 0, 0);
        break;
    case WM_DISPLAYCHANGE:
        if (state.fullscreen) PostMessageW(window, Refit, 0, 0);
        break;
    case WM_NCDESTROY:
        if (state.backdrop) DestroyWindow(state.backdrop);
        state = {};
        RemoveWindowSubclass(window, WindowProc, subclass);
        break;
    }
    return DefSubclassProc(window, message, key, flags);
}

LRESULT CALLBACK FindGameWindow(int code, WPARAM param, LPARAM data) {
    if (code >= 0 && !state.game) {
        const auto* message = reinterpret_cast<const CWPSTRUCT*>(data);
        if (message->message == WM_CREATE) {
            wchar_t name[128]{};
            GetClassNameW(message->hwnd, name, static_cast<int>(std::size(name)));
            if (std::wstring_view(name).starts_with(L"SRI_GameWindow_") &&
                SetWindowSubclass(message->hwnd, WindowProc, 1, 0)) {
                state.game = message->hwnd;
                PostMessageW(state.game, Initialize, 0, 0);
            }
        }
    }
    return CallNextHookEx(nullptr, code, param, data);
}

int Fail(const wchar_t* text) {
    MessageBoxW(nullptr, text, L"Lockpick Puzzle", MB_ICONERROR | MB_OK);
    return 1;
}
} // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    wchar_t executable[32768]{};
    const DWORD length = GetModuleFileNameW(nullptr, executable, static_cast<DWORD>(std::size(executable)));
    if (!length || length == std::size(executable)) return Fail(L"Could not locate the game installation.");
    const auto binary = std::filesystem::path(executable).parent_path() / L"bin" / L"sri_game.dll";
    HMODULE runtime = LoadLibraryExW(binary.c_str(), nullptr,
                                    LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!runtime) return Fail(L"Could not load the SRI game runtime from the bin folder.");
    using RunGame = int (*)();
    const auto run = reinterpret_cast<RunGame>(GetProcAddress(runtime, "SriRunGame"));
    if (!run) {
        FreeLibrary(runtime);
        return Fail(L"The installed runtime does not expose SriRunGame.");
    }
    // Observe and subclass only the game window created on this thread.
    HHOOK hook = SetWindowsHookExW(WH_CALLWNDPROC, FindGameWindow, nullptr, GetCurrentThreadId());
    if (!hook) {
        FreeLibrary(runtime);
        return Fail(L"Could not initialize the game window controls.");
    }
    const int result = run();
    UnhookWindowsHookEx(hook);
    // Keep the SRI runtime loaded until process exit so COM can finish teardown.
    return result;
}
