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

$ToolsetName = "v141_cl_llvm"
$LLVMDirectory = $LLVMDir

$rootDir = Split-Path -Parent $myInvocation.MyCommand.Definition | Split-Path -Parent
$assets = "$rootDir\assets"

if(!(Test-Path $LLVMDirectory)) {
    Install-Failed "LLVM not installed at $($LLVMDirectory)."
}

#we need to create this file to prevent a shim for clang.exe from being created by choco install
if (Test-Path $assets\clang.exe) {
    New-Item "$assets\clang.exe.ignore" -type file -force | Out-Null
}

function InstallArch ($arch) {
    $platformDir = "$VSInstallDir\Common7\IDE\VC\VCTargets\Platforms\$arch\PlatformToolsets";
    if (!(Test-Path $platformDir) -or $ToolsetName -eq "") {
        "Missing toolset directory for $($arch) or ToolsetName ($($ToolsetName)) not specified"
        return
    }

    $targetPath = "$platformDir\$ToolsetName"
    if (!(Test-Path $targetPath)) {
        New-Item -ItemType Directory $targetPath | Out-Null
    }
    
    Copy-Item "$assets\Toolset.targets" "$targetPath"
    $content = (Get-Content -Encoding UTF8 "$assets\Toolset.props") -replace "{{LLVMDir}}",$LLVMDirectory
    Set-Content "$targetPath\Toolset.props" $content -Encoding UTF8 | Out-Null

    if (!(Test-Path "$targetPath\bin")) {
      New-Item -ItemType Directory "$targetPath\bin" | Out-Null
    }

    if (Test-Path $assets\clang.exe) {
        Copy-Item $assets\clang.exe "$targetPath\bin\cl.exe"
        [IO.File]::WriteAllText("$targetPath\bin\.target","$LLVMDirectory\bin\clang-cl.exe");
    } else {
      cmd /C "mklink `"$targetPath\bin\cl.exe`" `"$LLVMDirectory\bin\clang-cl.exe`""
    }
    #LLVM's link.exe work-alike lld-link.exe not ready for prime time
    #cmd /C "mklink `"$targetPath\bin\link.exe`" `"$LLVMDirectory\bin\lld-link.exe`""

    "Installed $($ToolsetName) for $($arch)"
}

"Installing LLVM Integration Toolset $($ToolsetName)"
InstallArch "Win32"
InstallArch "x64"
