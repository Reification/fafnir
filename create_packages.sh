#!/bin/bash
projDir=$(dirname "${0}")
cd "$projDir"
projDir=$(pwd)

pkgName=$(echo *.nuspec)
pkgName=${pkgName/.nuspec/}
pkgVersion=$(sed 's:[<>]: :g' *.nuspec | gawk '/ version / { print $2; exit(0); }')

PATH=/c/devtools/cmake-android/bin:${PATH}

function buildBin() {
  if (which cmake 2>&1) > /dev/null; then
    echo > /dev/null
  else
    echo "cmake not installed or not in PATH" 1>&2
    exit 1
  fi

  (rm -rf build; mkdir build 2>&1) > /dev/null
  cd build

  if cmake -G "Visual Studio 15 2017 Win64" ..; then
    echo > /dev/null
  elif cmake -G "Visual Studio 16 2019" ..; then
    echo > /dev/null
  else  
    exit 1
  fi

  if cmake --build . --config Release --target INSTALL; then
    echo > /dev/null
  else
    exit 1
  fi

  cd "$projDir"
}

buildBin

(rm -rf ${pkgName}.${pkgVersion}/ ${pkgName}.${pkgVersion}.zip ${pkgName}.${pkgVersion}.nupkg 2>&1) > /dev/null

if (which nuget 2>&1) > /dev/null; then
  projDirW=$(cygpath -w "$projDir")
  nuget config -Set repositoryPath="$projDirW"
  #filter out the warnings about ChocolateyInstall.ps1 and ChocolateyUninstall.ps1 - they are actually incorrect
  (nuget pack -IncludeReferencedProjects -properties Configuration=Release 2>&1) | grep -v 'nstall\.ps1'
else
  echo "nuget not installed. skipping creation of ${pkgName}.${pkgVersion}.nupkg."
fi

cp -r out ${pkgName}.${pkgVersion}
cmake -E tar "cf" ${pkgName}.${pkgVersion}.zip --format=zip ${pkgName}.${pkgVersion}

echo "Manual installation archive packaged as ${pkgName}.${pkgVersion}.zip"

(rm -rf ${pkgName}.${pkgVersion}/ 2>&1) > /dev/null
