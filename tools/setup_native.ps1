$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$nativeSource = Join-Path $taskRoot 'android/app/src/main/cpp/LightGBM'
$revision = '8f7036f03627054d5a54a6f965b13f4b9ff2cb63'
if (-not (Test-Path -LiteralPath $nativeSource)) {
    git clone --depth 1 --branch v4.7.0 https://github.com/microsoft/LightGBM.git $nativeSource
    if ($LASTEXITCODE) { throw 'LightGBM clone failed' }
}
$actual = git -C $nativeSource rev-parse HEAD
if ($actual -ne $revision) { throw "Expected LightGBM $revision, found $actual" }
git -C $nativeSource submodule update --init --depth 1 external_libs/eigen external_libs/fast_double_parser external_libs/fmt external_libs/nanoarrow
if ($LASTEXITCODE) { throw 'LightGBM dependency download failed' }
