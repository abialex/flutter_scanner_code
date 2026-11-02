#ifndef FLUTTER_PLUGIN_SCANNER_CODE_PLUGIN_H_
#define FLUTTER_PLUGIN_SCANNER_CODE_PLUGIN_H_
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_SCANNER_CODE_EXPORT __declspec(dllexport)
#else
#define FLUTTER_SCANNER_CODE_EXPORT __declspec(dllimport)
#endif
#if defined(__cplusplus)
extern "C" {
#endif
FLUTTER_SCANNER_CODE_EXPORT void ScannerCodePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);
#if defined(__cplusplus)
}
#endif
#endif
