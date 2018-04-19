#ifndef FAFNIR_CUSTOM_API_HPP
#define FAFNIR_CUSTOM_API_HPP

#include <Windows.h>

#define FAFNIR_ENABLE_SPAM 1

#if FAFNIR_ENABLE_SPAM
# include <iostream>
# define FAFNIR_SPAM(...) { std::cout << __VA_ARGS__ ; }
# define FAFNIR_WSPAM(...) { std::wcout << __VA_ARGS__ ; }
#else
# define FAFNIR_SPAM(...)
# define FAFNIR_WSPAM(...)
#endif

namespace fafnir {

BOOL WINAPI create_process_w(
    LPCWSTR application_name,
    LPWSTR command_line,
    LPSECURITY_ATTRIBUTES process_attributes,
    LPSECURITY_ATTRIBUTES thread_attributes,
    BOOL inherit_handles,
    DWORD creation_flags,
    LPVOID environment,
    LPCWSTR current_directory,
    LPSTARTUPINFOW startup_info,
    LPPROCESS_INFORMATION process_information
);

BOOL WINAPI create_process_a(
    LPCSTR application_name,
    LPSTR command_line,
    LPSECURITY_ATTRIBUTES process_attributes,
    LPSECURITY_ATTRIBUTES thread_attributes,
    BOOL inherit_handles,
    DWORD creation_flags,
    LPVOID environment,
    LPCSTR current_directory,
    LPSTARTUPINFOA startup_info,
    LPPROCESS_INFORMATION process_information
);

BOOL WINAPI set_file_information_by_handle(
    HANDLE file,
    FILE_INFO_BY_HANDLE_CLASS information_class,
    LPVOID file_information,
    DWORD size
);

}

#endif
