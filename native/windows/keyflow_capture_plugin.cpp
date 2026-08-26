#include "keyflow_capture_plugin.h"

#include <windows.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/encodable_value.h>

#include "windows_startup_manager.h"

namespace keyflow {

void KeyflowCapturePlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<KeyflowCapturePlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

KeyflowCapturePlugin::KeyflowCapturePlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar_->messenger(),
      "keyflow/capture",
      &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar_->messenger(),
      "keyflow/capture/stream",
      &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const auto* arguments, auto sink) {
        std::lock_guard<std::mutex> lock(sink_mutex_);
        event_sink_ = std::move(sink);
        return nullptr;
      },
      [this](const auto* arguments) {
        std::lock_guard<std::mutex> lock(sink_mutex_);
        event_sink_ = nullptr;
        return nullptr;
      });

  event_channel_->SetStreamHandler(std::move(handler));

  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  if (hwnd) {
    tray_icon_.CreateTrayIcon(hwnd, NULL, [this](TrayMenuCommand cmd) {
      OnTrayCommand(cmd);
    });

    window_proc_delegate_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
          return HandleWindowMessage(hwnd, message, wParam, lParam);
        });
  }
}

KeyflowCapturePlugin::~KeyflowCapturePlugin() {
  if (window_proc_delegate_id_ != -1 && registrar_) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_delegate_id_);
  }
  WindowsCaptureEngine::GetInstance().StopCapture();
  tray_icon_.RemoveTrayIcon();
}

bool KeyflowCapturePlugin::HandleWindowMessage(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
  return tray_icon_.HandleWindowMessage(hwnd, message, wParam, lParam);
}

void KeyflowCapturePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "startCapture") {
    bool ok = WindowsCaptureEngine::GetInstance().StartCapture([this](const CapturedEvent& evt) {
      OnCapturedEvent(evt);
    });
    tray_icon_.UpdateStatus(false, L"KeyFlow - Active");
    result->Success(flutter::EncodableValue(ok));
  } else if (method == "stopCapture") {
    WindowsCaptureEngine::GetInstance().StopCapture();
    tray_icon_.UpdateStatus(true, L"KeyFlow - Stopped");
    result->Success(flutter::EncodableValue(true));
  } else if (method == "pauseCapture") {
    WindowsCaptureEngine::GetInstance().PauseCapture();
    tray_icon_.UpdateStatus(true, L"KeyFlow - Paused");
    result->Success(flutter::EncodableValue(true));
  } else if (method == "resumeCapture") {
    WindowsCaptureEngine::GetInstance().ResumeCapture();
    tray_icon_.UpdateStatus(false, L"KeyFlow - Active");
    result->Success(flutter::EncodableValue(true));
  } else if (method == "setExclusionList") {
    const auto* args = std::get_if<flutter::EncodableList>(method_call.arguments());
    std::vector<std::wstring> exclusion_list;
    if (args) {
      for (const auto& item : *args) {
        if (const auto* str = std::get_if<std::string>(&item)) {
          exclusion_list.push_back(WStringFromUtf8(*str));
        }
      }
    }
    WindowsCaptureEngine::GetInstance().SetExclusionList(exclusion_list);
    result->Success(flutter::EncodableValue(true));
  } else if (method == "setAutostart") {
    bool enable = false;
    if (const auto* val = std::get_if<bool>(method_call.arguments())) {
      enable = *val;
    }
    bool ok = WindowsStartupManager::SetAutostart(enable);
    result->Success(flutter::EncodableValue(ok));
  } else if (method == "isAutostartEnabled") {
    bool ok = WindowsStartupManager::IsAutostartEnabled();
    result->Success(flutter::EncodableValue(ok));
  } else {
    result->NotImplemented();
  }
}

void KeyflowCapturePlugin::OnCapturedEvent(const CapturedEvent& event) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  if (event_sink_) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("text")] = flutter::EncodableValue(Utf8FromWString(event.text));
    map[flutter::EncodableValue("app_name")] = flutter::EncodableValue(Utf8FromWString(event.app_name));
    map[flutter::EncodableValue("window_title")] = flutter::EncodableValue(Utf8FromWString(event.window_title));
    map[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(static_cast<int64_t>(event.timestamp_ms));

    event_sink_->Success(flutter::EncodableValue(map));
  }
}

void KeyflowCapturePlugin::OnTrayCommand(TrayMenuCommand command) {
  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  switch (command) {
    case TrayMenuCommand::kPause1Hour:
    case TrayMenuCommand::kPauseUntilReenabled:
      WindowsCaptureEngine::GetInstance().PauseCapture();
      tray_icon_.UpdateStatus(true, L"KeyFlow - Paused");
      if (method_channel_) {
        method_channel_->InvokeMethod("onPauseChanged", std::make_unique<flutter::EncodableValue>(true));
      }
      break;
    case TrayMenuCommand::kResume:
      WindowsCaptureEngine::GetInstance().ResumeCapture();
      tray_icon_.UpdateStatus(false, L"KeyFlow - Active");
      if (method_channel_) {
        method_channel_->InvokeMethod("onPauseChanged", std::make_unique<flutter::EncodableValue>(false));
      }
      break;
    case TrayMenuCommand::kOpenHistory:
      if (hwnd) {
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
      }
      if (method_channel_) {
        method_channel_->InvokeMethod("onNavigate", std::make_unique<flutter::EncodableValue>("history"));
      }
      break;
    case TrayMenuCommand::kOpenSettings:
      if (hwnd) {
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
      }
      if (method_channel_) {
        method_channel_->InvokeMethod("onNavigate", std::make_unique<flutter::EncodableValue>("settings"));
      }
      break;
    case TrayMenuCommand::kQuit:
      if (hwnd) {
        PostMessage(hwnd, WM_CLOSE, 0, 0);
      }
      break;
  }
}

std::string KeyflowCapturePlugin::Utf8FromWString(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &result[0], size, NULL, NULL);
  return result;
}

std::wstring KeyflowCapturePlugin::WStringFromUtf8(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
  std::wstring result(size, 0);
  MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &result[0], size);
  return result;
}

}  // namespace keyflow
