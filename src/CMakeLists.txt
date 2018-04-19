
if(BUILD_INJECTION_DLL)
  add_executable(clang main.cpp custom_api.cpp fafnir.h custom_api.h)
  add_library(fafnir_injection SHARED dll_main.cpp custom_api.cpp)
  target_link_libraries(fafnir_injection ImageHlp)
  target_compile_definitions(fafnir_injection PRIVATE FAFNIR_DLL)
  install(TARGETS fafnir_injection RUNTIME DESTINATION bin)
else()
  add_executable(clang main.cpp)
endif()

install(TARGETS clang RUNTIME DESTINATION bin)
