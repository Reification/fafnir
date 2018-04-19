#include <string_view>
#include <iostream>
#include <filesystem>
#include <fstream>

#include <vector>
#include <sstream>
#include <functional>

#include <Windows.h>

#include "unicode.hpp"
#include "fafnir.hpp"

#include "custom_api.hpp"

namespace fafnir {

enum class file_type {
    utf8,
    utf8_with_bom,
    utf16_le,
};

file_type get_file_type(std::istream& in) noexcept {
    char ch;
    in.read(&ch, 1);
    if (in) {
        if (ch == '\xff') {
            in.read(&ch, 1);
            if (in) {
                in.seekg(-2, std::ios::cur);
                if (ch == '\xfe') {
                    return file_type::utf16_le;
                }
            } else {
                in.seekg(-1, std::ios::cur);
            }
        } else if (ch == '\xef') {
            in.read(&ch, 1);
            if (in) {
                if (ch == '\xbb') {
                    in.read(&ch, 1);
                    if (in) {
                        in.seekg(-3, std::ios::cur);
                        if (ch == '\xbf') {
                            return file_type::utf8_with_bom;
                        }
                    } else {
                        in.seekg(-2, std::ios::cur);
                    }
                } else {
                    in.seekg(-2, std::ios::cur);
                }
            } else {
                in.seekg(-1, std::ios::cur);
            }
        } else {
            in.seekg(-1, std::ios::cur);
        }
    }
    in.clear();
    return file_type::utf8;
}

using read_func = std::function<char32_t ( std::istream& in )>;
using write_func = std::function<void ( std::ostream& out, char32_t ch )>;

std::string read_file_impl( const read_func& rf, const write_func& wf, std::istream& in ) noexcept
{
  std::ostringstream ss;

  for ( auto ch = rf( in ); ch != std::char_traits<char32_t>::eof(); ch = rf( in ) )
  {
    wf( ss, ch );
  }

  return ss.str();
}

std::string read_file( std::istream& in, const write_func& wf=&write_utf8_stream ) noexcept
{
  auto type = get_file_type( in );
  if ( type == file_type::utf8_with_bom )
  {
    in.seekg( 3 );
  }
  else if ( type == file_type::utf16_le )
  {
    in.seekg( 2 );
    return read_file_impl( &read_utf16_stream, wf, in );
  }
  return read_file_impl( &read_utf8_stream, wf, in );
}

std::experimental::filesystem::path read_path( std::istream& in ) noexcept
{
  std::string str = read_file( in, &write_utf16_stream );
  return {  reinterpret_cast<const wchar_t*>(str.data()),
            reinterpret_cast<const wchar_t*>(str.data() + str.size()) };
}

}

int main(int argc, char**argv) {
    using namespace fafnir;

    const char* exe_name = strrchr( argv[0], '\\' );
    exe_name = exe_name ? (exe_name + 1) : argv[0];

    if ( strstr( exe_name, "cl." ) || strstr( exe_name, "CL." ) )
    {
      if ( argv[argc - 1][0] != '@' )
      {
        const char* name = strrchr( argv[argc - 1], '\\' );
        name = name ? (name + 1) : argv[argc - 1];
        std::cout << name << "\n";
      }

      for ( int i = 1; i < argc; i++ )
      {
        if ( argv[i][0] == '@' )
        {
          std::string command = read_file( std::ifstream( argv[i] + 1, std::ios::binary ) );
          const char* name = strrchr( command.c_str(), '\\' );
          if ( !name )
          {
            name = strrchr( command.c_str(), ' ' );
            name = name ? (name + 1) : command.c_str();
          }
          else
          {
            name = name + 1;
          }
          std::cout << name << "\n";
        }
      }

      std::cout.flush();
    }

#if FAFNIR_ENABLE_SPAM
    FAFNIR_SPAM( "fafnir_clang as " << exe_name << "!\n" );

    {
      FAFNIR_SPAM( "###fafnir_args[\n" );
      for ( int i = 1; i < argc; i++ )
      {
        FAFNIR_SPAM( argv[i] << "\n" );
      }
      FAFNIR_SPAM( "--rsp-quoting=windows\n###]fafnir_args\n" );

      for ( int i = 1; i < argc; i++ )
      {
        if ( argv[i][0] == '@' )
        {
          const char* rspPath = argv[i] + 1;
          std::ifstream rsp( rspPath, std::ios::binary );

          FAFNIR_SPAM( "###fafnir_rsp" << i << "[\n" );

          if ( rsp.good() )
          {
            std::string rspBuf = read_file( rsp );
            FAFNIR_SPAM( rspBuf );
          }
          else
          {
            FAFNIR_SPAM( "failed opening '" << rspPath << "'\n" );
          }
          FAFNIR_SPAM( "\n###]fafnir_rsp" << i << "\n" );
        }
      }
    }
#endif

    auto path = get_bin_path() / ".target";
    if (!std::experimental::filesystem::exists(path)) {
        std::wcerr << "error: " << path << " doesn't exist." << std::endl;
        return 1;
    }
    std::ifstream target(path, std::ios::binary);
    auto target_path = read_path(target);
    target.close();
    if (!std::experimental::filesystem::exists(target_path)) {
        std::wcerr << "error: " << target_path << " doesn't exist." << std::endl;
        return 1;
    }
    const std::wstring_view cmdline = GetCommandLineW();
    auto itr = cmdline.begin();
    while (itr != cmdline.end() && *itr != ' ') {
        if (*itr == '"') {
            ++itr;
            while (itr != cmdline.end() && *itr != '"') {
                ++itr;
            }
        }
        ++itr;
    }

    std::vector<wchar_t> cmdbuf;
    auto new_cmdline = cmdline.substr(itr - cmdline.begin());
    cmdbuf.reserve(target_path.native().size() + new_cmdline.size() + 3);
    cmdbuf.push_back('"');
    cmdbuf.insert(cmdbuf.end(), target_path.native().begin(), target_path.native().end());
    cmdbuf.push_back('"');
    cmdbuf.insert(cmdbuf.end(), new_cmdline.begin(), new_cmdline.end());
    cmdbuf.push_back(L'\0');
    STARTUPINFOW si{sizeof(si)};
    PROCESS_INFORMATION pi{};

#if FAFNIR_USE_INJECTION
    create_process_w(target_path.c_str(), cmdbuf.data(), nullptr, nullptr, true, 0, nullptr, nullptr, &si, &pi);
#else
    CreateProcessW( target_path.c_str(), cmdbuf.data(), nullptr, nullptr, true, 0, nullptr, nullptr, &si, &pi );
#endif

    const handle_ptr process{pi.hProcess};
    const handle_ptr thread{pi.hThread};
    WaitForSingleObject(process.get(), INFINITE);
    DWORD exit_code;
    GetExitCodeProcess(process.get(), &exit_code);
    return exit_code;
}
