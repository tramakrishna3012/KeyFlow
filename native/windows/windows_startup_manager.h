#ifndef NATIVE_WINDOWS_STARTUP_MANAGER_H_
#define NATIVE_WINDOWS_STARTUP_MANAGER_H_

#include <windows.h>
#include <string>

namespace keyflow {

class WindowsStartupManager {
 public:
  static bool SetAutostart(bool enable);
  static bool IsAutostartEnabled();

 private:
  static constexpr const wchar_t* kRegistrySubKey = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
  static constexpr const wchar_t* kAppName = L"KeyFlow";
};

}  // namespace keyflow

#endif  // NATIVE_WINDOWS_STARTUP_MANAGER_H_
