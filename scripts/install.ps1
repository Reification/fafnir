param($LLVMDirectory = "", $ClangClToolsetName = "", [switch]$Noprompt = $false, [switch]$Uninstall = $false)
$id=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal=new-object System.Security.Principal.WindowsPrincipal($id)

$role=[System.Security.Principal.WindowsBuiltInRole]::Administrator
if (!$principal.IsInRole($role)) {
   $pinfo = New-Object System.Diagnostics.ProcessStartInfo "powershell"
   [string[]]$arguments = @("-NoExit", "-ExecutionPolicy","Bypass",$myInvocation.MyCommand.Definition)
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
if (!$LLVMDir) {
    $LLVMDir = "C:\Program Files\LLVM"
}
if (!$VSInstallDir) {
    Install-Failed "Visual Studio 2017 is not found."
}

$DefaultClangClToolsetName = "v141_cl_llvm"
$clangClPath = ""
$clangPath = ""

$reset = $false
$interactive = $true
$installing = $true
$verb = "install"

#"LLVMDirectory[arg]: $($LLVMDirectory)"
#"ClangClToolsetName[arg]: $($ClangClToolsetName)"
#"Noprompt[arg]: $($Noprompt)"
#"Uninstall[arg]: $($Uninstall)"

if($Noprompt) {
    $interactive = $false
    if(!$LLVMDirectory) {
        $LLVMDirectory = "default"
    }
    if(!$ClangCLToolsetName) {
        $ClangCLToosetName = "default"
    }
}

if($Uninstall) {
    $LLVMDirectory = "LLVM_PATH_NOT_USED_FOR_UNINSTALL"
    $installing = $false
    $verb = "uninstall"
}

if($LLVMDirectory -eq "default") {
    $LLVMDirectory = $LLVMDir    
}

if($ClangClToolsetName -eq "default") {
    $ClangClToolsetName = $DefaultClangClToolsetName
}


#"LLVMDirectory[eff]: $($LLVMDirectory)"
#"ClangClToolsetName[eff]: $($ClangClToolsetName)"
#"installing: $($installing)"
#"interactive: $($interactive)"

if($interactive) {
    do {
        if ($installing -and ($reset -or $LLVMDirectory -eq "")) {
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
                $clangClPath = "$LLVMDirectory\bin\clang-cl.exe"
                if (!(Test-Path $clangPath)) {
                    Install-Failed("$clangPath doesn't exist.")
                }
                break
            }
        }

        if ($reset -or ($ClangClToolsetName -eq "")) {
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
        "=== configuration ==="
        if($installing) {
            "* LLVM install directory: $LLVMDirectory"
            if(!(Test-Path "$clangClPath")) {
                Install-Failed("$clangClPath does not exist.")
            }
        }
 
        "* Clang-cl toolset: $ClangClToolsetName"
        ""
        $reset = $true
    } while((Read-Host "Is it OK to $($verb)? (Y/n)") -match "n|no")
}

$rootDir = Split-Path -Parent $myInvocation.MyCommand.Definition | Split-Path -Parent
$assets = "$rootDir\assets"
$bin = "$rootDir\bin\clang.exe"

function InstallArch ($arch) {
    $platformDir = "$VSInstallDir\Common7\IDE\VC\VCTargets\Platforms\$arch\PlatformToolsets";
    if (!(Test-Path $platformDir)) {
        return
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
            if (!(Test-Path "$targetPath\bin")) {
                New-Item -ItemType Directory "$targetPath\bin"
            }
            Copy-Item $bin "$targetPath\bin\cl.exe"
            [IO.File]::WriteAllText("$targetPath\bin\.target","$LLVMDirectory\bin\clang-cl.exe");
        }
        "Installed $($ClangClToolsetName) for $($arch)"
    }
}

function UninstallArch($arch) {
    $platformDir = "$VSInstallDir\Common7\IDE\VC\VCTargets\Platforms\$arch\PlatformToolsets";
    if (!(Test-Path $platformDir)) {
        return
    }

    if ($ClangClToolsetName -ne "") {
        $targetPath = "$platformDir\$ClangClToolsetName"
        if (Test-Path $targetPath) {
            Remove-Item -path "$targetPath" -recurse
            "Uninstalled $($ClangClToolsetName) for $($arch)"
        }
    }    
}

if($installing) {
    "Installing LLVM Integration Toolsets $($ClangClToosetName)"
    InstallArch "Win32"
    InstallArch "x64"
} else {
    "Uninstalling LLVM Integration Toolsets $($ClangClToosetName)"
    UninstallArch "Win32"
    UninstallArch "x64"    
}
