//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
#include <bonsoir_windows/bonsoir_windows_plugin_c_api.h>
#include <local_notifier/local_notifier_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  BitsdojoWindowPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("BitsdojoWindowPlugin"));
  BonsoirWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("BonsoirWindowsPluginCApi"));
  LocalNotifierPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("LocalNotifierPlugin"));
}
