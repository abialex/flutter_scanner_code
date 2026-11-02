cmake_minimum_required(VERSION 3.14)
project(flutter_scanner_code LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "flutter_scanner_code_plugin")
add_library(${PLUGIN_NAME} SHARED
  "scanner_code_plugin.cpp"
  "scanner_code_api.g.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX)
target_include_directories(${PLUGIN_NAME}
  PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include"
  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include/flutter_scanner_code")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  setupapi.lib
  user32.lib
)
set(flutter_scanner_code_bundled_libraries "" PARENT_SCOPE)
