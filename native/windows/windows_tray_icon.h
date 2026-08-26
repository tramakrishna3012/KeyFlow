#ifndef NATIVE_WINDOWS_TRAY_ICON_H_
#define NATIVE_WINDOWS_TRAY_ICON_H_

#include <windows.h>
#include <shellapi.h>
#include <functional>
#include <string>

namespace keyflow {

enum class TrayMenuCommand {
  kPause1Hour,
  kPauseUntilReenabled,
  kResume,
  kOpenHistory,
  kOpenSettings,
  kQuit
};

using TrayCommandCallback = std::function<void(TrayMenuCommand command)>;

class WindowsTrayIcon {
 public:
  static constexpr UINT kWM_TRAYICON = WM_USER + 101;

  WindowsTrayIcon();
  ~WindowsTrayIcon();

  bool CreateTrayIcon(HWND parent_hwnd, HICON hIcon, TrayCommandCallback callback);
  void RemoveTrayIcon();

  void UpdateStatus(bool is_paused, const std::wstring& tooltip_text);
  void ShowContextMenu();

  bool HandleWindowMessage(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);

 private:
  HWND parent_hwnd_{nullptr};
  NOTIFYICONDATAW nid_{};
  TrayCommandCallback callback_{nullptr};
  bool is_paused_{false};
};

}  // namespace keyflow

#endif  // NATIVE_WINDOWS_TRAY_ICON_H_
