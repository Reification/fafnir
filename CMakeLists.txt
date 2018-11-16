cmake_minimum_required(VERSION 3.10)

project(fafnir LANGUAGES CXX VERSION 1.0.1.1)

set(BUILD_TESTS false CACHE BOOL "Generate test projects or not")
set(BUILD_INJECTION_DLL false CACHE BOOL "Build and use injection dll or not")
set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}/out" CACHE STRING "Install location" FORCE)

if("${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang|GNU|Intel")
    if("${CMAKE_CXX_COMPILER}" MATCHES "/cl.exe")
      message(STATUS "Clang-CL C++17")
      set(CMAKE_CXX_FLAGS "/std:c++17 ${CMAKE_CXX_FLAGS} -Wno-unused-command-line-argument")
    else()
        message(STATUS "${CMAKE_CXX_COMPILER_ID} C++17")
      set(CMAKE_CXX_FLAGS "-std=c++17 ${CMAKE_CXX_FLAGS}")
    endif()
elseif("${CMAKE_CXX_COMPILER_ID}" MATCHES "MSVC")
    message(STATUS "${CMAKE_CXX_COMPILER_ID} C++17")
    set(CMAKE_CXX_FLAGS "/std:c++17 ${CMAKE_CXX_FLAGS}")
else()
    message(WARNING "'${CMAKE_CXX_COMPILER_ID}' not recognized - C++17 standard not enabled!")
endif()

add_definitions(-DFAFNIR_USE_INJECTION=0)

if(BUILD_TESTS)
  enable_testing()
endif()

add_subdirectory(src)

if(BUILD_TESTS)
  add_subdirectory(tests)
endif()

make_directory("${CMAKE_INSTALL_PREFIX}")
install(FILES install.bat uninstall.bat README.md README_ja.md LICENSE DESTINATION ".")
install(DIRECTORY scripts assets DESTINATION ".")
