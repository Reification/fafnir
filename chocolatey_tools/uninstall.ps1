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
if (!$VSInstallDir) {
    Install-Failed "Visual Studio 2017 is not found."
}

$ToolsetName = "v141_cl_llvm"

function UninstallArch($arch) {
    $platformDir = "$VSInstallDir\Common7\IDE\VC\VCTargets\Platforms\$arch\PlatformToolsets";
    $targetPath = "$platformDir\$ToolsetName"
    
    if ($ToolsetName -eq "" -or !(Test-Path $targetPath)) {
        "Toolset $($ToolsetName) for $($arch) was not installed."
        return
    }
 
    Remove-Item -path "$targetPath" -recurse
    "Uninstalled $($ToolsetName) for $($arch)"
}

"Uninstalling LLVM Integration Toolset $($ToolsetName)"
UninstallArch "Win32"
UninstallArch "x64"    
