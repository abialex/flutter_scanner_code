#include <windows.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cwctype>
#include <iterator>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include <initguid.h>
#include <devpkey.h>
#include <flutter/encodable_value.h>
#include <flutter/plugin_registrar_windows.h>
#include <setupapi.h>

#include "include/flutter_scanner_code/scanner_code_plugin.h"
#include "include/flutter_scanner_code/scanner_code_api.g.h"

namespace flutter_scanner_code {
namespace {

std::wstring DevicePathWide(HANDLE device) {
  UINT length = 0;
  if (GetRawInputDeviceInfoW(device, RIDI_DEVICENAME, nullptr, &length) ==
          UINT(-1) ||
      length == 0) {
    return {};
  }

  std::wstring path(length, L'\0');
  if (GetRawInputDeviceInfoW(device, RIDI_DEVICENAME, path.data(), &length) ==
      UINT(-1)) {
    return {};
  }
  if (!path.empty() && path.back() == L'\0') path.pop_back();
  return path;
}

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return {};

  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr,
                                       0, nullptr, nullptr);
  if (size <= 1) return {};

  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, result.data(), size,
                      nullptr, nullptr);
  result.pop_back();
  return result;
}

struct DeviceIdentity {
  std::wstring wide_path;
  std::string path;
  std::string vendor_id;
  std::string product_id;
  std::string interface_number;
  std::string instance_id;
  std::string collection_id;
  std::string interface_class_id;
};

struct BarcodeBuffer {
  std::wstring value;
  bool shift_pressed = false;
  bool overflowed = false;
};

std::wstring Uppercase(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t character) {
                   return static_cast<wchar_t>(std::towupper(character));
                 });
  return value;
}

std::wstring ExtractPathValue(const std::wstring& source,
                              const std::wstring& key) {
  const auto uppercase_source = Uppercase(source);
  const auto uppercase_key = Uppercase(key);
  const auto key_position = uppercase_source.find(uppercase_key);
  if (key_position == std::wstring::npos) return {};

  const auto value_start = key_position + uppercase_key.size();
  const auto value_end = source.find_first_of(L"&#\\{}", value_start);
  return source.substr(value_start, value_end - value_start);
}

std::vector<std::wstring> SplitDevicePath(const std::wstring& path) {
  std::vector<std::wstring> parts;
  size_t part_start = 0;
  while (part_start <= path.size()) {
    const auto separator = path.find(L'#', part_start);
    parts.push_back(path.substr(part_start, separator - part_start));
    if (separator == std::wstring::npos) break;
    part_start = separator + 1;
  }
  return parts;
}

DeviceIdentity ParseDevicePath(std::wstring path) {
  DeviceIdentity identity;
  identity.wide_path = std::move(path);
  identity.path = ToUtf8(identity.wide_path);

  const auto path_parts = SplitDevicePath(identity.wide_path);
  const auto& hardware_attributes =
      path_parts.size() > 1 ? path_parts[1] : identity.wide_path;
  if (path_parts.size() > 2) {
    identity.instance_id = ToUtf8(path_parts[2]);
  }
  if (path_parts.size() > 3) {
    identity.interface_class_id = ToUtf8(path_parts.back());
  }

  identity.vendor_id = ToUtf8(ExtractPathValue(hardware_attributes, L"VID_"));
  identity.product_id = ToUtf8(ExtractPathValue(hardware_attributes, L"PID_"));
  identity.interface_number =
      ToUtf8(ExtractPathValue(hardware_attributes, L"MI_"));
  identity.collection_id = ToUtf8(ExtractPathValue(identity.wide_path, L"COL"));
  return identity;
}

std::wstring ReadDeviceProperty(HDEVINFO device_info_set,
                                SP_DEVINFO_DATA& device_info,
                                const DEVPROPKEY& property_key) {
  DEVPROPTYPE property_type = 0;
  DWORD required_size = 0;
  if (SetupDiGetDevicePropertyW(device_info_set, &device_info, &property_key,
                                &property_type, nullptr, 0, &required_size,
                                0) ||
      GetLastError() != ERROR_INSUFFICIENT_BUFFER || required_size == 0) {
    return {};
  }

  std::vector<BYTE> buffer(required_size + sizeof(wchar_t), 0);
  if (!SetupDiGetDevicePropertyW(
          device_info_set, &device_info, &property_key, &property_type,
          buffer.data(), required_size, &required_size, 0) ||
      property_type != DEVPROP_TYPE_STRING) {
    return {};
  }

  return std::wstring(reinterpret_cast<const wchar_t*>(buffer.data()));
}

std::wstring ReadDeviceNodeName(HDEVINFO device_info_set,
                                SP_DEVINFO_DATA& device_info) {
  auto name = ReadDeviceProperty(device_info_set, device_info,
                                 DEVPKEY_Device_FriendlyName);
  if (name.empty()) {
    name = ReadDeviceProperty(device_info_set, device_info,
                              DEVPKEY_Device_BusReportedDeviceDesc);
  }
  if (name.empty()) {
    name = ReadDeviceProperty(device_info_set, device_info,
                              DEVPKEY_Device_DeviceDesc);
  }
  return name;
}

bool IsGenericDeviceName(const std::wstring& name) {
  const auto uppercase_name = Uppercase(name);
  static const std::vector<std::wstring> generic_names = {
      L"DISPOSITIVO DE TECLADO HID",
      L"DISPOSITIVO DEFINIDO POR EL PROVEEDOR COMPATIBLE CON HID",
      L"DISPOSITIVO COMPATIBLE CON HID",
      L"DISPOSITIVO DE CONTROL DEL CONSUMIDOR COMPATIBLE CON HID",
      L"DISPOSITIVO COMPUESTO USB",
      L"DISPOSITIVO DE ENTRADA USB",
      L"DISPOSITIVO BLUETOOTH DE BAJO CONSUMO",
      L"DISPOSITIVO BLUETOOTH DE BAJO CONSUMO HID COMPATIBLE CON GATT",
      L"HID KEYBOARD DEVICE",
      L"HID-COMPLIANT VENDOR-DEFINED DEVICE",
      L"HID-COMPLIANT DEVICE",
      L"USB COMPOSITE DEVICE",
      L"USB INPUT DEVICE",
      L"USB KEYBOARD",
      L"BLUETOOTH LOW ENERGY DEVICE",
      L"BLUETOOTH LOW ENERGY HID DEVICE",
  };
  if (std::find(generic_names.begin(), generic_names.end(), uppercase_name) !=
      generic_names.end()) {
    return true;
  }
  return uppercase_name.rfind(L"BLUETOOTH LE SERVICE ", 0) == 0;
}

bool IsGenericManufacturer(const std::wstring& manufacturer) {
  const auto uppercase_manufacturer = Uppercase(manufacturer);
  return uppercase_manufacturer.empty() ||
         uppercase_manufacturer == L"MICROSOFT" ||
         uppercase_manufacturer.rfind(L"(TECLADOS EST", 0) == 0 ||
         uppercase_manufacturer.rfind(L"(DISPOSITIVOS DE SISTEMA EST", 0) ==
             0 ||
         uppercase_manufacturer.rfind(L"(CONTROLADORA DE HOST USB", 0) == 0 ||
         uppercase_manufacturer == L"(STANDARD KEYBOARDS)" ||
         uppercase_manufacturer == L"(STANDARD SYSTEM DEVICES)" ||
         uppercase_manufacturer == L"(STANDARD USB HOST CONTROLLER)";
}

std::wstring DeviceTransport(const std::wstring& instance_id) {
  const auto uppercase_id = Uppercase(instance_id);
  if (uppercase_id.rfind(L"BTHLE\\DEV_", 0) == 0 ||
      uppercase_id.rfind(L"BTHENUM\\DEV_", 0) == 0) {
    return L"Bluetooth";
  }
  if (uppercase_id.rfind(L"USB\\", 0) == 0) return L"USB";
  if (uppercase_id.rfind(L"SUPERDISPLAY\\", 0) == 0) return L"Virtual";
  return {};
}

bool IsBluetoothDeviceInstanceId(const std::wstring& instance_id) {
  std::wstring uppercase_id(instance_id);
  std::transform(uppercase_id.begin(), uppercase_id.end(),
                 uppercase_id.begin(), [](wchar_t character) {
                   return static_cast<wchar_t>(std::towupper(character));
                 });

  // Skip Bluetooth service nodes such as BTHLEDEVICE, whose descriptions are
  // generic (for example, "Bluetooth LE HID over GATT"). Continue to the
  // physical Bluetooth device node, which carries the user's friendly name.
  return uppercase_id.rfind(L"BTHENUM\\DEV_", 0) == 0 ||
         uppercase_id.rfind(L"BTHLE\\DEV_", 0) == 0;
}

struct DevicePresentation {
  std::wstring display_name;
  std::wstring manufacturer;
  std::wstring transport;
};

DevicePresentation DevicePresentationFor(const std::wstring& interface_path) {
  DevicePresentation presentation;
  HDEVINFO device_info_set = SetupDiCreateDeviceInfoList(nullptr, nullptr);
  if (device_info_set == INVALID_HANDLE_VALUE) return presentation;

  SP_DEVICE_INTERFACE_DATA interface_data{};
  interface_data.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);
  if (!SetupDiOpenDeviceInterfaceW(device_info_set, interface_path.c_str(), 0,
                                   &interface_data)) {
    SetupDiDestroyDeviceInfoList(device_info_set);
    return presentation;
  }

  SP_DEVINFO_DATA device_info{};
  device_info.cbSize = sizeof(SP_DEVINFO_DATA);
  DWORD required_size = 0;
  const BOOL detail_read = SetupDiGetDeviceInterfaceDetailW(
      device_info_set, &interface_data, nullptr, 0, &required_size,
      &device_info);
  if (!detail_read && GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
    SetupDiDestroyDeviceInfoList(device_info_set);
    return presentation;
  }

  presentation.display_name = ReadDeviceNodeName(device_info_set, device_info);
  auto manufacturer = ReadDeviceProperty(
      device_info_set, device_info, DEVPKEY_Device_Manufacturer);
  if (!IsGenericManufacturer(manufacturer)) {
    presentation.manufacturer = std::move(manufacturer);
  }

  for (int depth = 0; depth < 6; ++depth) {
    const auto parent_id = ReadDeviceProperty(
        device_info_set, device_info, DEVPKEY_Device_Parent);
    if (parent_id.empty()) break;

    SP_DEVINFO_DATA parent_info{};
    parent_info.cbSize = sizeof(SP_DEVINFO_DATA);
    if (!SetupDiOpenDeviceInfoW(device_info_set, parent_id.c_str(), nullptr, 0,
                                &parent_info)) {
      break;
    }

    const auto parent_transport = DeviceTransport(parent_id);
    if (presentation.transport.empty() && !parent_transport.empty()) {
      presentation.transport = parent_transport;
    }

    auto parent_name = ReadDeviceNodeName(device_info_set, parent_info);
    const bool is_physical_bluetooth_device =
        IsBluetoothDeviceInstanceId(parent_id);
    if (is_physical_bluetooth_device && !parent_name.empty()) {
      presentation.display_name = std::move(parent_name);
      manufacturer = ReadDeviceProperty(
          device_info_set, parent_info, DEVPKEY_Device_Manufacturer);
      if (!IsGenericManufacturer(manufacturer)) {
        presentation.manufacturer = std::move(manufacturer);
      }
      break;
    }

    if (!parent_name.empty() && !IsGenericDeviceName(parent_name) &&
        (presentation.display_name.empty() ||
         IsGenericDeviceName(presentation.display_name))) {
      presentation.display_name = std::move(parent_name);
      manufacturer = ReadDeviceProperty(
          device_info_set, parent_info, DEVPKEY_Device_Manufacturer);
      if (!IsGenericManufacturer(manufacturer)) {
        presentation.manufacturer = std::move(manufacturer);
      }
    }

    if (presentation.manufacturer.empty()) {
      manufacturer = ReadDeviceProperty(
          device_info_set, parent_info, DEVPKEY_Device_Manufacturer);
      if (!IsGenericManufacturer(manufacturer)) {
        presentation.manufacturer = std::move(manufacturer);
      }
    }
    device_info = parent_info;
  }

  if (IsGenericDeviceName(presentation.display_name)) {
    if (presentation.transport == L"USB") {
      presentation.display_name = L"Teclado USB";
    } else if (presentation.transport == L"Virtual") {
      presentation.display_name = L"Teclado virtual";
    }
  }

  SetupDiDestroyDeviceInfoList(device_info_set);
  return presentation;
}

class ScannerCodePlugin : public flutter::Plugin, public ScannerCodeHostApi {
 public:
  explicit ScannerCodePlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar), callbacks_(registrar->messenger()) {}

  ~ScannerCodePlugin() override {
    StopCapture();
    ScannerCodeHostApi::SetUp(registrar_->messenger(), nullptr);
  }

  ErrorOr<flutter::EncodableList> ListKeyboardDevices() override {
    UINT count = 0;
    if (GetRawInputDeviceList(nullptr, &count,
                              sizeof(RAWINPUTDEVICELIST)) == UINT(-1)) {
      return FlutterError("device_enumeration_failed",
                          "Windows could not enumerate keyboard devices.");
    }

    std::vector<RAWINPUTDEVICELIST> devices(count);
    if (count > 0 &&
        GetRawInputDeviceList(devices.data(), &count,
                              sizeof(RAWINPUTDEVICELIST)) == UINT(-1)) {
      return FlutterError("device_enumeration_failed",
                          "Windows could not read keyboard devices.");
    }

    flutter::EncodableList result;
    for (const auto& device : devices) {
      if (device.dwType != RIM_TYPEKEYBOARD) continue;

      const auto identity = ParseDevicePath(DevicePathWide(device.hDevice));
      if (identity.path.empty()) continue;
      const auto presentation = DevicePresentationFor(identity.wide_path);

      result.emplace_back(flutter::CustomEncodableValue(
          ScannerDeviceInfo(identity.path, identity.vendor_id,
                            identity.product_id, identity.interface_number,
                            identity.instance_id, identity.collection_id,
                            identity.interface_class_id,
                            ToUtf8(presentation.display_name),
                            ToUtf8(presentation.manufacturer),
                            ToUtf8(presentation.transport),
                            identity.path == last_device_path_)));
    }
    return result;
  }

  ErrorOr<ScannerInputPolicyResultData> ConfigureInputPolicy(
      const ScannerInputPolicyData& policy) override {
    const auto previous_device_path = suppressed_device_path_;
    suppressed_device_path_ =
        policy.device_path() == nullptr ? "" : *policy.device_path();
    forwarded_keys_.clear();
    barcode_buffers_.clear();
    if (capturing_ && !RegisterKeyboardInput()) {
      suppressed_device_path_ = previous_device_path;
      const std::string message =
          "Windows could not apply the selected keyboard filter.";
      return ScannerInputPolicyResultData(
          ScannerInputPolicyStatusData::kUnsupported, &message);
    }

    const std::string message =
        suppressed_device_path_.empty()
            ? "No keyboard is selected for suppression."
            : capturing_
                  ? "Selected keyboard input is suppressed; other keyboards "
                    "are forwarded."
                  : "The selected keyboard will be suppressed when capture "
                    "starts.";
    return ScannerInputPolicyResultData(ScannerInputPolicyStatusData::kApplied,
                                        &message);
  }

  std::optional<FlutterError> StartCapture() override {
    if (capturing_) return std::nullopt;

    auto* view = registrar_->GetView();
    if (view == nullptr) {
      return FlutterError("window_unavailable",
                          "The Flutter window is unavailable.");
    }

    const HWND view_window = view->GetNativeWindow();
    target_window_ = GetAncestor(view_window, GA_ROOT);
    if (target_window_ == nullptr) target_window_ = view_window;

    if (delegate_id_ < 0) {
      delegate_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
          [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
            return HandleMessage(window, message, wparam, lparam);
          });
    }

    if (!RegisterKeyboardInput()) {
      registrar_->UnregisterTopLevelWindowProcDelegate(delegate_id_);
      delegate_id_ = -1;
      target_window_ = nullptr;
      return FlutterError("capture_registration_failed",
                          "Windows could not register keyboard input.");
    }

    capturing_ = true;
    return std::nullopt;
  }

  std::optional<FlutterError> StopCapture() override {
    if (!capturing_) return std::nullopt;

    RAWINPUTDEVICE keyboard{};
    keyboard.usUsagePage = 0x01;
    keyboard.usUsage = 0x06;
    keyboard.dwFlags = RIDEV_REMOVE;
    const bool removed =
        RegisterRawInputDevices(&keyboard, 1, sizeof(keyboard)) != FALSE;

    registrar_->UnregisterTopLevelWindowProcDelegate(delegate_id_);
    delegate_id_ = -1;
    capturing_ = false;
    target_window_ = nullptr;
    forwarded_keys_.clear();
    barcode_buffers_.clear();

    if (!removed) {
      return FlutterError("capture_stop_failed",
                          "Windows could not stop keyboard capture.");
    }
    return std::nullopt;
  }

 private:
  bool RegisterKeyboardInput() {
    if (target_window_ == nullptr) return false;

    RAWINPUTDEVICE keyboard{};
    keyboard.usUsagePage = 0x01;
    keyboard.usUsage = 0x06;
    keyboard.dwFlags = RIDEV_INPUTSINK;
    if (!suppressed_device_path_.empty()) {
      // Windows cannot disable legacy typing for only one HID keyboard.
      // Disable it for this app and forward Raw Input from every other device.
      keyboard.dwFlags |= RIDEV_NOLEGACY;
    }
    keyboard.hwndTarget = target_window_;
    return RegisterRawInputDevices(&keyboard, 1, sizeof(keyboard)) != FALSE;
  }

  static std::string ForwardedKeyId(const std::string& device_path,
                                    const RAWKEYBOARD& key) {
    return device_path + ":" + std::to_string(key.VKey) + ":" +
           std::to_string(key.MakeCode) + ":" +
           std::to_string(key.Flags & (RI_KEY_E0 | RI_KEY_E1));
  }

  void ForwardKeyboardInput(const DeviceIdentity& identity,
                            const RAWKEYBOARD& key) {
    if (suppressed_device_path_.empty() ||
        identity.path == suppressed_device_path_) {
      return;
    }

    const HWND foreground = GetForegroundWindow();
    if (foreground == nullptr ||
        GetAncestor(foreground, GA_ROOT) != target_window_) {
      forwarded_keys_.clear();
      return;
    }

    if (key.Message != WM_KEYDOWN && key.Message != WM_KEYUP &&
        key.Message != WM_SYSKEYDOWN && key.Message != WM_SYSKEYUP) {
      return;
    }

    const auto key_id = ForwardedKeyId(identity.path, key);
    const bool key_up = (key.Flags & RI_KEY_BREAK) != 0;
    const bool was_down =
        forwarded_keys_.find(key_id) != forwarded_keys_.end();
    if (key_up && !was_down) return;

    if (key_up) {
      forwarded_keys_.erase(key_id);
    } else {
      forwarded_keys_.insert(key_id);
    }

    // Inject into the Windows keyboard stream so the key state queried by
    // Flutter matches the forwarded event, especially for Ctrl and Alt.
    INPUT input{};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = 0;
    input.ki.wScan = key.MakeCode;
    input.ki.dwFlags = KEYEVENTF_SCANCODE;
    if ((key.Flags & RI_KEY_E0) != 0) {
      input.ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
    }
    if (key_up) input.ki.dwFlags |= KEYEVENTF_KEYUP;
    if (key.MakeCode == 0) {
      input.ki.wVk = key.VKey;
      input.ki.dwFlags &= ~KEYEVENTF_SCANCODE;
    }
    SendInput(1, &input, sizeof(INPUT));
  }

  void ProcessBarcodeInput(const DeviceIdentity& identity,
                           const RAWKEYBOARD& key) {
    if (suppressed_device_path_.empty() ||
        identity.path != suppressed_device_path_) {
      return;
    }

    auto& buffer = barcode_buffers_[identity.path];
    const bool key_up = (key.Flags & RI_KEY_BREAK) != 0;
    const bool is_shift = key.VKey == VK_SHIFT || key.VKey == VK_LSHIFT ||
                          key.VKey == VK_RSHIFT;
    if (is_shift) {
      buffer.shift_pressed = !key_up;
      return;
    }
    if (key_up) return;

    if (key.VKey == VK_RETURN || key.VKey == VK_SEPARATOR) {
      if (!buffer.overflowed && !buffer.value.empty()) {
        const auto code = ToUtf8(buffer.value);
        if (!code.empty()) {
          callbacks_.OnBarcode(code, identity.path, []() {},
                               [](const FlutterError&) {});
        }
      }
      buffer.value.clear();
      buffer.overflowed = false;
      return;
    }

    if (key.VKey == VK_BACK) {
      if (buffer.overflowed) {
        buffer.value.clear();
        buffer.overflowed = false;
      } else if (!buffer.value.empty()) {
        buffer.value.pop_back();
      }
      return;
    }

    BYTE keyboard_state[256]{};
    GetKeyboardState(keyboard_state);
    const BYTE shift_state = buffer.shift_pressed ? 0x80 : 0;
    keyboard_state[VK_SHIFT] = shift_state;
    keyboard_state[VK_LSHIFT] = shift_state;
    keyboard_state[VK_RSHIFT] = shift_state;

    wchar_t characters[8]{};
    const int character_count = ToUnicodeEx(
        key.VKey, key.MakeCode, keyboard_state, characters,
        static_cast<int>(std::size(characters)), 4, GetKeyboardLayout(0));
    if (character_count <= 0) return;

    constexpr size_t max_barcode_length = 512;
    const auto new_length = buffer.value.size() + character_count;
    if (new_length > max_barcode_length) {
      buffer.value.clear();
      buffer.overflowed = true;
      return;
    }

    for (int index = 0; index < character_count; ++index) {
      const auto character = characters[index];
      if (character >= L' ' && character != 0x7f) {
        buffer.value.push_back(character);
      }
    }
  }

  std::optional<LRESULT> HandleMessage(HWND window, UINT message,
                                       WPARAM wparam, LPARAM lparam) {
    if (message != WM_INPUT) return std::nullopt;

    UINT size = 0;
    const UINT query_result = GetRawInputData(
        reinterpret_cast<HRAWINPUT>(lparam), RID_INPUT, nullptr, &size,
        sizeof(RAWINPUTHEADER));
    const UINT minimum_keyboard_size =
        static_cast<UINT>(offsetof(RAWINPUT, data) + sizeof(RAWKEYBOARD));

    if (query_result != UINT(-1) && size >= minimum_keyboard_size) {
      std::vector<BYTE> buffer(size);
      const UINT bytes_read = GetRawInputData(
          reinterpret_cast<HRAWINPUT>(lparam), RID_INPUT, buffer.data(), &size,
          sizeof(RAWINPUTHEADER));

      if (bytes_read != UINT(-1) && bytes_read >= minimum_keyboard_size) {
        const auto* input = reinterpret_cast<const RAWINPUT*>(buffer.data());
        if (input->header.dwType == RIM_TYPEKEYBOARD) {
          const auto& key = input->data.keyboard;
          const auto identity =
              ParseDevicePath(DevicePathWide(input->header.hDevice));
          last_device_path_ = identity.path;
          ProcessBarcodeInput(identity, key);
          if ((key.Flags & RI_KEY_BREAK) == 0) {
            PublishKey(identity, key.VKey);
          }
          if (key.VKey != 0 && key.VKey != 0xff &&
              GET_RAWINPUT_CODE_WPARAM(wparam) == RIM_INPUT) {
            ForwardKeyboardInput(identity, key);
          }
        }
      }
    }

    // The default window procedure must clean up each foreground WM_INPUT.
    return DefWindowProcW(window, message, wparam, lparam);
  }

  void PublishKey(const DeviceIdentity& identity, USHORT virtual_key) {
    callbacks_.OnKeyPressed(
        ScannerKeyInfo(identity.path, identity.vendor_id, identity.product_id,
                       identity.interface_number, identity.instance_id,
                       identity.collection_id, identity.interface_class_id,
                       static_cast<int64_t>(virtual_key)),
        []() {}, [](const FlutterError&) {});
  }

  flutter::PluginRegistrarWindows* registrar_;
  ScannerCodeFlutterApi callbacks_;
  int delegate_id_ = -1;
  HWND target_window_ = nullptr;
  std::string last_device_path_;
  std::string suppressed_device_path_;
  std::set<std::string> forwarded_keys_;
  std::map<std::string, BarcodeBuffer> barcode_buffers_;
  bool capturing_ = false;
};

}  // namespace
}  // namespace flutter_scanner_code

void ScannerCodePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  auto plugin =
      std::make_unique<flutter_scanner_code::ScannerCodePlugin>(
          windows_registrar);
  flutter_scanner_code::ScannerCodeHostApi::SetUp(windows_registrar->messenger(),
                                                  plugin.get());
  windows_registrar->AddPlugin(std::move(plugin));
}
