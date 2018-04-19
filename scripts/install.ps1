param($LLVMDirectory = "", $ToolsetName = "", $ClangClToolsetName = "")
$id=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal=new-object System.Security.Principal.WindowsPrincipal($id)

$role=[System.Security.Principal.WindowsBuiltInRole]::Administrator
if (!$principal.IsInRole($role)) {
   $pinfo = New-Object System.Diagnostics.ProcessStartInfo "powershell"
   [string[]]$arguments = @("-ExecutionPolicy","Bypass",$myInvocation.MyCommand.Definition)
   foreach ($key in $myInvocation.BoundParameters.Keys) {
       $arguments += ,@("-$key")
       $arguments += ,@($myInvocation.BoundParameters[$key])
    }
   $pinfo.Arguments = $arguments
   $pinfo.Verb = "runas"
   $null = [System.Diagnostics.Process]::Start($pinfo)
   exit
}
$Host.UI.RawUI.WindowTitle = "Fafnir - Clang MSBuild toolset installer"

function Install-Failed($message) {
    Write-Error $message
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

function Get-Registry($key, $valuekey = "") {
    $reg = Get-Item -Path $key -ErrorAction SilentlyContinue
    if ($reg) {
        return $reg.GetValue($valuekey)
    }
    return $null
}

$VSInstallDir = Get-Registry Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VS7 "15.0"
if (!$VSInstallDir) {
    $VSInstallDir = Get-Registry Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7 "15.0"
}
$LLVMDir = Get-Registry Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LLVM\LLVM -ErrorAction 
if (!$LLVMDir) {
    $LLVMDir = Get-Registry Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\LLVM\LLVM
}

if (!$VSInstallDir) {
    Install-Failed "Visual Studio 2017 is not found."
}

$reset = $false

$DefaultToolsetName = "v140_clang_llvm"
$DefaultClangClToolsetName = "v140_cl_llvm"

do {
    if ($reset -or $LLVMDirectory -eq "") {
        for(;;) {
            $prompt = "Where is the LLVM Directory?"
            if ($LLVMDirectory -ne "") {
                $prompt += " (current: $LLVMDirectory)"
            } elseif ($LLVMDir -ne "") {
                $prompt += " (default: $LLVMDir)"
            }
            $tmp = Read-Host $prompt
            if ($tmp -eq "") {
                if ($LLVMDirectory -eq "") {
                    $LLVMDirectory = $LLVMDir
                }
            } else {
                $LLVMDirectory = $tmp
            }
            if ($LLVMDirectory -eq "") {
                "LLVM directory must be specified."
                continue
            }
            $clangPath = "$LLVMDirectory\bin\clang.exe"
            if (!(Test-Path $clangPath)) {
                if (!((Read-Host "$clangPath doesn't exist. Would you like to continue installation? (y/N)") -match "y|yes")) {
                    $LLVMDirectory = ""
                    continue
                }
            }
            break
        }
    }

    if ($reset -or ($ToolsetName -eq "" -and -not ((Read-Host "Do you want to install a toolset for clang? (Y/n)") -match "n|no"))) {    
        $prompt = "What is the clang toolset name?"
        if ($reset) {
            $prompt += "(current: $ToolsetName)" 
        } else {
            $prompt += " (default: $DefaultToolsetName)"
        }
        $tmp = Read-Host $prompt
        if ($tmp -eq "" -and $ToolsetName -eq "") {
            $ToolsetName = $DefaultToolsetName
        } else {
            $ToolsetName = $tmp
        }
    }
    
    if ($reset -or ($ClangClToolsetName -eq "" -and -not ((Read-Host "Do you want to install a toolset for clang-cl? (Y/n)") -match "n|no"))) {
        $prompt = "What is the clang-cl toolset name?"
        if ($reset) {
            $prompt += "(current: $ClangClToolsetName)" 
        } else {
            $prompt += " (default: $DefaultClangClToolsetName)"
        }
        $tmp = Read-Host $prompt
        if ($tmp -eq "" -and $ClangClToolsetName -eq "") {
            $ClangClToolsetName = $DefaultClangClToolsetName
        } else {
            $ClangClToolsetName = $tmp
        }
    }
    
    ""
    "=== Install configuration ==="
    "* LLVM install directory: $LLVMDirectory"
    if ($ToolsetName -eq "") {
        "* Clang toolset won't install."
    } else {
        "* Clang toolset name: $ToolsetName"
    }
    if ($ClangClToolsetName -eq "") {
        "* Clang-cl toolset won't install."
    } else {
        "* Clang-cl toolset: $ClangClToolsetName"
    }
    ""
    $reset = $true
} while((Read-Host "Is it OK to install? (Y/n)") -match "n|no")

$rootDir = Split-Path -Parent $myInvocation.MyCommand.Definition | Split-Path -Parent
$assets = "$rootDir\assets"
$bin = "$rootDir\bin\clang.exe"
$dll = "$rootDir\bin\fafnir_injection.dll"

function Install ($arch) {
    $platformDir = "$VSInstallDir\Common7\IDE\VC\VCTargets\Platforms\$arch\PlatformToolsets";
    if (!(Test-Path $platformDir)) {
        return
    }

    if ($ToolsetName -ne "") {
        $targetPath = "$platformDir\$ToolsetName"        
        if (!(Test-Path $targetPath)) {
            New-Item -ItemType Directory $targetPath
        }
        Copy-Item "$assets\clang\Toolset.targets" "$targetPath"
        $content = (Get-Content -Encoding UTF8 "$assets\clang\Toolset.props") -replace "{{LLVMDir}}",$LLVMDirectory
        Set-Content "$targetPath\Toolset.props" $content -Encoding UTF8
        if (!(Test-Path "$targetPath\bin")) {
            New-Item -ItemType Directory "$targetPath\bin"
        }
        Copy-Item $bin "$targetPath\bin\"
        Copy-Item $dll "$targetPath\bin\"
        [IO.File]::WriteAllText("$targetPath\bin\.target","$LLVMDirectory\bin\clang.exe");

        if (!(Test-Path "$targetPath\link-bin")) {
            New-Item -ItemType Directory "$targetPath\link-bin"
        }
        Copy-Item $bin "$targetPath\link-bin\lld-link.exe"
        Copy-Item $dll "$targetPath\link-bin\"
        [IO.File]::WriteAllText("$targetPath\link-bin\.target","$LLVMDirectory\bin\lld-link.exe");
    }

    if ($ClangClToolsetName -ne "") {
        $targetPath = "$platformDir\$ClangClToolsetName"
        if (!(Test-Path $targetPath)) {
            New-Item -ItemType Directory $targetPath
        }
        Copy-Item "$assets\clang-cl\Toolset.targets" "$targetPath"
        $content = (Get-Content -Encoding UTF8 "$assets\clang-cl\Toolset.props") -replace "{{LLVMDir}}",$LLVMDirectory
        Set-Content "$targetPath\Toolset.props" $content -Encoding UTF8 | Out-Null
        if (Test-Path $bin) {
            if (!(Test-Path "$targetPath\msbuild-bin")) {
                New-Item -ItemType Directory "$targetPath\msbuild-bin"
            }
            Copy-Item $bin "$targetPath\msbuild-bin\cl.exe"
            Copy-Item $dll "$targetPath\msbuild-bin\"
            [IO.File]::WriteAllText("$targetPath\msbuild-bin\.target","$LLVMDirectory\msbuild-bin\cl.exe");
        }
    }
}

Install "Win32"
Install "x64"

Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
""
