[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $EditorDir,
    [Parameter(Mandatory)] [string] $OutputDir
)

$ErrorActionPreference = 'Stop'
$editor = (Resolve-Path -LiteralPath $EditorDir).Path
$destination = [IO.Path]::GetFullPath($OutputDir)
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../lockpick_puzzle.sriproject')).Path
$compiler = (Get-Command cl.exe -ErrorAction Stop).Source
$source = Join-Path $PSScriptRoot 'LockpickLauncher.cpp'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("lockpick-launcher-" + [guid]::NewGuid().ToString('N'))
$launcher = Join-Path $temp 'lockpick_puzzle.exe'
$object = Join-Path $temp 'LockpickLauncher.obj'

New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $compilerArgs = @('/nologo', '/std:c++20', '/O2', '/MT', '/EHsc', '/W4', '/DUNICODE', '/D_UNICODE',
        "/Fo$object", "/Fe$launcher", $source, '/link', '/SUBSYSTEM:WINDOWS', '/MACHINE:X64',
        'user32.lib', 'gdi32.lib', 'comctl32.lib')
    & $compiler @compilerArgs
    if ($LASTEXITCODE -ne 0) { throw "Lockpick launcher compilation failed ($LASTEXITCODE)." }

    $packageArgs = @('--project', $project, '--out', $destination, '--runtime', (Join-Path $editor 'runtime'),
        '--width', '1280', '--height', '960', '--no-pak')
    & (Join-Path $editor 'sri-build.exe') @packageArgs
    if ($LASTEXITCODE -ne 0) { throw "SRI packaging failed ($LASTEXITCODE)." }
    Copy-Item -LiteralPath $launcher -Destination (Join-Path $destination 'lockpick_puzzle.exe') -Force
} finally {
    foreach ($file in @($object, $launcher)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    Remove-Item -LiteralPath $temp
}
