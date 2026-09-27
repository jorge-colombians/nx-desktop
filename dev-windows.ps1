# SPDX-FileCopyrightText: 2026 CMC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Dev helper for Windows: installs every build requirement (via winget/Craft),
# then configures, builds, runs, tests and packages the CMC desktop client.
# Mirrors dev-ubuntu.sh's UX; the underlying toolchain is KDE Craft, since
# Windows installers/deps must be built with the real MSVC toolset (see
# README.md "Building installers" for background).
#
# Interactive:      .\dev-windows.ps1
# Non-interactive:  .\dev-windows.ps1 <install|build|run|build-run|test|installer|clean> [-Local|-Prod] [-Reset]
#
#   -Local   point the dev build at LocalServerUrl (default http://localhost:8080)
#   -Prod    point the dev build at the production server (default)
#   -Reset   delete the client config before running, so the first-run wizard shows again
#
# "build"/"run"/"build-run" always produce the dev build (NEXTCLOUD_DEV=ON,
# exe "cmcdev.exe"), same as dev-ubuntu.sh. "installer" produces the real
# production NSIS/MSI installer ("cmc.exe") via Craft's --package step.
#
# Safe to run repeatedly: already-installed requirements are skipped, and the
# known CMC-rebrand patches to the upstream craft-blueprints-nextcloud repo
# (see README's "Windows (NSIS/MSI installer)" note) are (re-)applied
# automatically whenever they're missing, e.g. after a fresh blueprint clone.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'build', 'run', 'build-run', 'test', 'installer', 'clean')]
    [string]$Action,
    [switch]$Local,
    [switch]$Prod,
    [switch]$Reset
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- settings ---
$SrcDir              = $PSScriptRoot
$CraftTarget         = 'windows-msvc2022_64-cl'
$CraftMasterDir      = Join-Path $SrcDir 'CraftMaster'
$CraftMasterPy       = Join-Path $CraftMasterDir 'CraftMaster.py'
$CraftMasterConfig   = Join-Path $SrcDir 'craftmaster.ini'
$CraftMasterOverride = Join-Path $SrcDir 'craftmaster.local.ini'
$DefaultCraftRoot    = 'C:\craft-nc'   # short path: avoids MAX_PATH failures deep in Craft's own build/cache paths

$BlueprintKdeUrl        = 'https://github.com/nextcloud/craft-blueprints-kde.git|stable-34.0|'
$BlueprintNextcloudUrl  = 'https://github.com/nextcloud/craft-blueprints-nextcloud.git|stable-34.0|'

$LocalServerUrl = if ($env:LOCAL_SERVER_URL) { $env:LOCAL_SERVER_URL } else { 'http://localhost:8080' }

$WingetPackages = @(
    @{ Id = 'Git.Git';                 Cmd = 'git' }
    @{ Id = 'Python.Python.3.12';      Cmd = $null }   # checked separately via `py -3.12`
    @{ Id = 'Inkscape.Inkscape';       Cmd = 'inkscape' }
    @{ Id = 'OpenCppCoverage.OpenCppCoverage'; Cmd = $null }  # used by "test"; optional, best-effort
)

# ----------------------------------------------------------------- helpers ---
function Info { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Ok   { param([string]$Msg) Write-Host "OK  $Msg" -ForegroundColor Green }
function Warn { param([string]$Msg) Write-Host "!   $Msg" -ForegroundColor Yellow }
function Die  { param([string]$Msg) Write-Host "X   $Msg" -ForegroundColor Red; exit 1 }

function Confirm-Ask {
    param([string]$Prompt, [bool]$Default = $false)
    $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $reply = Read-Host "$Prompt $hint"
    if ([string]::IsNullOrWhiteSpace($reply)) { return $Default }
    return $reply -match '^(?i:y)'
}

function Select-Choice {
    param([string]$Title, [string[]]$Options)
    Write-Host ''
    Write-Host $Title
    for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host "  $($i + 1)) $($Options[$i])" }
    while ($true) {
        $reply = Read-Host "Choice [1-$($Options.Count)]"
        if ($reply -match '^\d+$' -and [int]$reply -ge 1 -and [int]$reply -le $Options.Count) { return [int]$reply }
        Write-Host "Please type a number between 1 and $($Options.Count)."
    }
}

# ------------------------------------------------------------- environment ---
function Get-CraftRoot {
    if (Test-Path $CraftMasterOverride) {
        $line = Select-String -Path $CraftMasterOverride -Pattern '^\s*Root\s*=\s*(.+)$' | Select-Object -First 1
        if ($line) { return $line.Matches[0].Groups[1].Value.Trim() }
    }
    return $DefaultCraftRoot
}

# Native-exe stderr must not be redirected under $ErrorActionPreference='Stop' (PS 5.1 wraps
# each stderr line into a terminating ErrorRecord even on a clean, expected non-zero exit).
# Scope ErrorActionPreference to 'Continue' around the probe instead, and check $LASTEXITCODE.
function Test-Py312 {
    if (-not (Get-Command py -ErrorAction SilentlyContinue)) { return $false }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & py -3.12 -c "" 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return $code -eq 0
}

function Get-PythonExe {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        if (Test-Py312) { return @('py', '-3.12') }
        return @('py')
    }
    if (Get-Command python -ErrorAction SilentlyContinue) { return @('python') }
    Die "No Python found on PATH. Run '.\dev-windows.ps1 install' first."
}

function Invoke-Craft {
    # Plain (non-advanced) function taking a single array param: passing "-i" etc. via
    # ValueFromRemainingArguments would make this an advanced function and PowerShell's
    # binder then ambiguously prefix-matches "-i" against -InformationAction/-InformationVariable
    # before it ever reaches remaining-args collection. Always call with -CraftArgs @(...).
    param([string[]]$CraftArgs)
    # @(...) forces array context: a bare `$py = Get-PythonExe` would silently unwrap to a plain
    # string when Get-PythonExe emits a single-element array (PowerShell's default pipeline
    # enumeration collapses one-element arrays), and $py[0] would then index into the STRING's
    # characters (giving 'p', not 'py') instead of the array's first element.
    $py = @(Get-PythonExe)
    $configArgs = @('--config', $CraftMasterConfig)
    if (Test-Path $CraftMasterOverride) { $configArgs += @('--config-override', $CraftMasterOverride) }
    $exe = $py[0]
    # $py[1..($py.Count-1)] would be the descending range 1..0 when Count=1 (a single 'py' with
    # no version flag), and indexing with a descending range re-picks index 0 instead of being
    # empty - so guard the single-element case explicitly rather than slicing blindly.
    $pyVersionArgs = if ($py.Count -gt 1) { @($py[1..($py.Count - 1)]) } else { @() }
    $pyArgs = $pyVersionArgs + @($CraftMasterPy) + $configArgs + @('--target', $CraftTarget, '-c') + $CraftArgs
    & $exe @pyArgs
    if ($LASTEXITCODE -ne 0) { Die "craft $($CraftArgs -join ' ') failed (exit $LASTEXITCODE)" }
}

$script:CraftRoot   = Get-CraftRoot
$script:CraftTargetDir = Join-Path $script:CraftRoot $CraftTarget
$script:MergedBin      = Join-Path $script:CraftTargetDir 'bin'
$script:WorkBuildDir   = Join-Path $script:CraftTargetDir 'build\nextcloud-client\work\build'
$script:BlueprintDir   = Join-Path $script:CraftTargetDir 'etc\blueprints\locations\craft-blueprints-nextcloud\nextcloud-client'

# ----------------------------------------------------------------- install ---
function Test-VCToolsInstalled {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $false }
    $path = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    return -not [string]::IsNullOrWhiteSpace($path)
}

function Install-Requirements {
    Info 'Checking winget-managed tools'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Die 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
    }
    foreach ($pkg in $WingetPackages) {
        if ($pkg.Cmd -and (Get-Command $pkg.Cmd -ErrorAction SilentlyContinue)) { Ok "$($pkg.Id) already available ($($pkg.Cmd))"; continue }
        if ($pkg.Id -eq 'Python.Python.3.12') {
            if (Test-Py312) { Ok 'Python 3.12 already available'; continue }
        }
        Info "Installing $($pkg.Id)"
        winget install --id $pkg.Id --exact --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Warn "winget install $($pkg.Id) failed (exit $LASTEXITCODE) - continuing" }
    }

    Info 'Checking MSVC C++ toolset'
    if (Test-VCToolsInstalled) {
        Ok 'MSVC C++ toolset already installed'
    } else {
        Info 'Installing Visual Studio 2022 Build Tools (C++ workload) - this takes a while'
        winget install --id Microsoft.VisualStudio.2022.BuildTools --silent `
            --accept-package-agreements --accept-source-agreements `
            --override '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
        if (-not (Test-VCToolsInstalled)) { Die 'MSVC C++ toolset still not found after install. Install Visual Studio manually with the "Desktop development with C++" workload.' }
        Ok 'MSVC C++ toolset installed'
    }

    if (-not (Test-Path $CraftMasterDir)) {
        Info 'Cloning CraftMaster'
        git clone -q --depth=1 https://invent.kde.org/packaging/craftmaster.git $CraftMasterDir
    } else {
        Ok 'CraftMaster already cloned'
    }

    if (-not (Test-Path $CraftMasterOverride)) {
        Info "Creating $CraftMasterOverride (Craft root: $DefaultCraftRoot)"
        @(
            '# Local override, not tracked in git.'
            '# Keeps the Craft root short to avoid Windows MAX_PATH (260 char) failures'
            '# during deep Qt/KDE Frameworks builds. See CraftMaster --config-override.'
            '[Variables]'
            "Root = $DefaultCraftRoot"
        ) | Set-Content -Path $CraftMasterOverride -Encoding utf8
        $script:CraftRoot     = Get-CraftRoot
        $script:CraftTargetDir = Join-Path $script:CraftRoot $CraftTarget
        $script:MergedBin      = Join-Path $script:CraftTargetDir 'bin'
        $script:WorkBuildDir   = Join-Path $script:CraftTargetDir 'build\nextcloud-client\work\build'
        $script:BlueprintDir   = Join-Path $script:CraftTargetDir 'etc\blueprints\locations\craft-blueprints-nextcloud\nextcloud-client'
    }

    if (-not (Test-Path (Join-Path $script:CraftTargetDir 'etc\blueprints\locations\craft-blueprints-kde'))) {
        Info 'Adding KDE blueprint repository'
        Invoke-Craft -CraftArgs @('--add-blueprint-repository', $BlueprintKdeUrl)
    }
    if (-not (Test-Path $script:BlueprintDir)) {
        Info 'Adding Nextcloud blueprint repository'
        Invoke-Craft -CraftArgs @('--add-blueprint-repository', $BlueprintNextcloudUrl)
    }

    Info 'Bootstrapping Craft itself (safe to re-run)'
    Invoke-Craft -CraftArgs @('craft')

    Repair-NextcloudBlueprint

    Info 'Installing nextcloud-client dependencies (Qt, KArchive, QtKeychain, ...) - this takes a while'
    Invoke-Craft -CraftArgs @('--install-deps', 'nextcloud-client')

    Ok 'All requirements installed'
}

# Rewrites the upstream craft-blueprints-nextcloud repo's nextcloud-client.py/blacklist.txt:
# 1. CMC-rebrand gaps (see README.md): missing `import os`, the cmc/cmccmd exe blacklist
#    pattern, and branding fields (description/displayName/defines/applicationExecutable).
# 2. An upstream bug: registerOptions() only registers overrideServerUrl/forceOverrideServerUrl
#    under `if CraftCore.compiler.isMacOS:`, but __init__ reads them unconditionally on every
#    platform - so building on Windows/Linux crashes with "has no registered option
#    overrideServerUrl" unless those two registerOption() calls are pulled out of that block.
# 3. defines["icon"] is never set, so PackagerBase.setDefaults() defaults the installer's icon
#    (and its uninstaller entry) to Craft's own generic craft.ico - point it at the CMC.ico our
#    own build already generates under buildDir()/src/gui/.
# Marker-based (branding fields) skip-check doesn't cover fixes #2/#3, so this always redeploys
# the known-good file rather than trying to detect partial-patch drift.
function Repair-NextcloudBlueprint {
    $pyFile  = Join-Path $script:BlueprintDir 'nextcloud-client.py'
    $blFile  = Join-Path $script:BlueprintDir 'blacklist.txt'
    if (-not (Test-Path $pyFile)) { return }   # blueprint repo not fetched yet

    $content = Get-Content $pyFile -Raw
    $goodContent = @'
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-FileCopyrightText: 2021 Nextcloud GmbH and Nextcloud contributors

import os

import info
from Package.CMakePackageBase import *

class subinfo(info.infoclass):
    def registerOptions(self):
        self.options.dynamic.registerOption("devMode", False)
        self.options.dynamic.registerOption("versionSuffix", "")
        self.options.dynamic.registerOption("buildWithWebEngine", True)
        # These two are read unconditionally in __init__ below, so they must be registered on
        # every platform - not just macOS, which is where upstream originally (buggily) nested them.
        self.options.dynamic.registerOption("overrideServerUrl", "")
        self.options.dynamic.registerOption("forceOverrideServerUrl", False)
        if CraftCore.compiler.isMacOS:
            self.options.dynamic.registerOption("osxArchs", "arm64")
            self.options.dynamic.registerOption("buildMacOSBundle", True)
            self.options.dynamic.registerOption("buildFileProviderModule", False)
            self.options.dynamic.registerOption("sparkleLibPath", "")

    def setTargets(self):
        self.svnTargets["master"] = "[git]https://github.com/nextcloud/desktop"

        self.description = "CMC Desktop Client"
        self.displayName = "CMC"
        self.webpage = "https://nextcloud.com"

        self.defaultTarget = "master"

    def setDependencies(self):
        self.buildDependencies["dev-utils/cmake"] = None
        self.runtimeDependencies["libs/qt6/qtbase"] = None
        self.runtimeDependencies["libs/qt6/qtdeclarative"] = None

        if self.options.dynamic.buildWithWebEngine:
            self.runtimeDependencies["libs/qt6/qtwebengine"] = None

        self.runtimeDependencies["libs/qt6/qtwebsockets"] = None
        self.runtimeDependencies["libs/qt/qtsvg"] = None
        self.runtimeDependencies["libs/qt6/qt5compat"] = None
        self.runtimeDependencies["libs/zlib"] = None
        self.runtimeDependencies["libs/libp11"] = None
        self.runtimeDependencies["libs/kdsingleapplication"] = None
        self.runtimeDependencies["qt-libs/qtkeychain"] = None
        self.runtimeDependencies["kde/frameworks/tier1/karchive"] = None
        if CraftCore.compiler.isLinux:
            self.runtimeDependencies["kde/frameworks/tier1/kdbusaddons"] = None

        self.runtimeDependencies["libs/openssl"] = None

class Package(CMakePackageBase):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        def boolToCmakeBool(value: bool) -> str:
            return "ON" if value else "OFF"

        devMode = self.subinfo.options.dynamic.devMode
        versionSuffix = self.subinfo.options.dynamic.versionSuffix
        overrideServerUrl = self.subinfo.options.dynamic.overrideServerUrl

        # Make sure we do not set the application server url to empty if it is not set, this can
        # unintentionally break our use of NEXTCLOUD.cmake
        if overrideServerUrl:
            forceOverrideServerUrl = "ON" if self.subinfo.options.dynamic.forceOverrideServerUrl == True else "OFF"
            self.subinfo.options.configure.args += [
                f"-DAPPLICATION_SERVER_URL={overrideServerUrl}",
                f"-DAPPLICATION_SERVER_URL_ENFORCE={forceOverrideServerUrl}"
            ]

        if devMode:
            self.subinfo.options.configure.args += [f"-DNEXTCLOUD_DEV=ON"]

        self.subinfo.options.configure.args += [f"-DMIRALL_VERSION_SUFFIX={versionSuffix}"]

        buildWithWebEngine = boolToCmakeBool(self.subinfo.options.dynamic.buildWithWebEngine)
        self.subinfo.options.configure.args += [f"-DBUILD_WITH_WEBENGINE={buildWithWebEngine}"]

        if CraftCore.compiler.isMacOS:
            osxArchs = self.subinfo.options.dynamic.osxArchs
            buildAppBundle = boolToCmakeBool(self.subinfo.options.dynamic.buildMacOSBundle)
            buildFileProviderModule = boolToCmakeBool(self.subinfo.options.dynamic.buildFileProviderModule)
            sparkleLibPath = self.subinfo.options.dynamic.sparkleLibPath
            self.subinfo.options.configure.args += [
                f"-DCMAKE_OSX_ARCHITECTURES={osxArchs}",
                f"-DBUILD_OWNCLOUD_OSX_BUNDLE={buildAppBundle}",
                f"-DBUILD_FILE_PROVIDER_MODULE={buildFileProviderModule}",
                f"-DSPARKLE_LIBRARY={sparkleLibPath}",
            ]

    def createPackage(self):
        self.blacklist_file.append(os.path.join(self.packageDir(), 'blacklist.txt'))
        self.defines["appname"] = "cmc"
        self.defines["company"] = "Cloudmail City"
        self.defines["executable"] = "bin\\cmc.exe"
        self.applicationExecutable = "cmc"
        self.defines["icon"] = self.buildDir() / "src" / "gui" / "CMC.ico"

        self.ignoredPackages += ["binary/mysql"]
        if not CraftCore.compiler.isLinux:
            self.ignoredPackages += ["libs/dbus"]

        return super().createPackage()
'@
    if ($content -ne $goodContent) {
        Info 'Patching nextcloud-client.py (CMC branding + cross-platform overrideServerUrl fix)'
        if (-not (Test-Path "$pyFile.orig")) { Copy-Item $pyFile "$pyFile.orig" }
        Set-Content -Path $pyFile -NoNewline -Encoding utf8 -Value $goodContent
        Ok 'nextcloud-client.py patched (pristine upstream copy saved as nextcloud-client.py.orig)'
    }

    if (Test-Path $blFile) {
        $bl = Get-Content $blFile -Raw
        $needle = 'bin/(?!(nextcloud|nextcloudcmd|QtWebEngineProcess)).*\.exe'
        if ($bl.Contains($needle)) {
            Info 'Patching blacklist.txt exe whitelist (nextcloud/nextcloudcmd -> cmc/cmccmd)'
            $bl.Replace($needle, 'bin/(?!(cmc|cmccmd|QtWebEngineProcess)).*\.exe') | Set-Content -Path $blFile -NoNewline -Encoding utf8
            Ok 'blacklist.txt patched'
        }
    }
}

# ------------------------------------------------------------- build / run ---
function Get-CraftOptions {
    param([string]$Target, [bool]$DevMode)
    $overrideUrl = if ($Target -eq 'local') { $LocalServerUrl } else { '' }
    return @(
        '--options', "nextcloud-client.srcDir=$SrcDir",
        '--options', "nextcloud-client.devMode=$DevMode",
        '--options', "nextcloud-client.overrideServerUrl=$overrideUrl",
        '--options', 'nextcloud-client.forceOverrideServerUrl=False'
    )
}

function Invoke-Build {
    param([string]$Target)
    Repair-NextcloudBlueprint
    $opts = @(Get-CraftOptions -Target $Target -DevMode $true)
    Info "Building (dev, $Target server)"
    Invoke-Craft -CraftArgs ($opts + @('-i', 'nextcloud-client'))
    $exe = Join-Path $script:MergedBin 'cmcdev.exe'
    if (-not (Test-Path $exe)) { Die "Build finished but $exe was not found - check the Craft log above." }
    Ok "Build finished: $exe"
}

function Reset-Config {
    $cfg = "$env:APPDATA\CMCDev\cmcdev.cfg"
    if (Test-Path $cfg) {
        Remove-Item $cfg -Force
        Ok "Deleted $cfg (the first-run wizard will show)"
    } else {
        Ok "No config to reset ($cfg does not exist)"
    }
}

function Invoke-Run {
    param([bool]$DoReset)
    $exe = Join-Path $script:MergedBin 'cmcdev.exe'
    if (-not (Test-Path $exe)) { Die "$exe not found, build first" }
    Get-Process -Name cmcdev -ErrorAction SilentlyContinue | ForEach-Object {
        Info 'Stopping running cmcdev'
        Stop-Process -Id $_.Id -Force
        Start-Sleep -Seconds 1
    }
    if ($DoReset) { Reset-Config }
    Info "Running $exe - logs: $env:APPDATA\CMCDev\logs"
    Start-Process -FilePath $exe
}

function Invoke-Test {
    Repair-NextcloudBlueprint
    $opts = @(Get-CraftOptions -Target 'prod' -DevMode $true)
    Info 'Building with tests enabled'
    Invoke-Craft -CraftArgs ($opts + @('-i', 'nextcloud-client'))
    if (-not (Test-Path $script:WorkBuildDir)) { Die "Build directory not found: $script:WorkBuildDir" }
    Info "Running ctest in $script:WorkBuildDir"
    Push-Location $script:WorkBuildDir
    try {
        ctest --output-on-failure --timeout 300
        if ($LASTEXITCODE -ne 0) { Die "ctest failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
    Ok 'All tests passed'
}

function Invoke-Installer {
    Repair-NextcloudBlueprint
    $opts = @(Get-CraftOptions -Target 'prod' -DevMode $false)
    Info 'Building production client'
    Invoke-Craft -CraftArgs ($opts + @('-i', 'nextcloud-client'))
    Info 'Packaging installer (NSIS/MSI via CPack) - this takes a while'
    Invoke-Craft -CraftArgs ($opts + @('--package', 'nextcloud-client'))

    $dist = Join-Path $SrcDir 'dist'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    # CPack/NSIS stages the packaged installer under the Craft root's own tmp\ folder
    # (named nextcloud-client-<version>-...-x86_64.exe), NOT under the raw cmake build
    # tree - that tree only has the unpackaged bin\ output (exe + every test binary,
    # which is why a loose "setup|install" name match used to pick a *Test.exe by mistake).
    $packagingTmp = Join-Path $script:CraftTargetDir 'tmp'
    # -Include is silently a no-op unless -Path itself ends in a wildcard (a long-standing
    # PowerShell quirk) - "$packagingTmp" alone would return zero results even though the
    # installer is right there.
    $installer = Get-ChildItem -Path "$packagingTmp\*" -Include '*.exe', '*.msi' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'nextcloud-client-*' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $installer) { Die "No installer found under $packagingTmp - check the Craft log above." }
    Copy-Item $installer.FullName -Destination $dist -Force
    Ok "Installer ready: $dist\$($installer.Name)"
}

function Invoke-Clean {
    if (-not (Test-Path $script:WorkBuildDir)) { Ok 'Nothing to clean'; return }
    Write-Host "Build folder: $script:WorkBuildDir"
    if (-not $Interactive -or (Confirm-Ask 'Delete it (forces a full reconfigure next build)?' $false)) {
        Remove-Item -Recurse -Force $script:WorkBuildDir
        Ok 'Deleted'
    }
}

# ------------------------------------------------------------------ combos ---
function Invoke-BuildRunLoop {
    param([string]$InitialAction, [string]$Target, [bool]$InitialReset)
    $action = $InitialAction; $doReset = $InitialReset
    while ($true) {
        if ($action -eq 'build' -or $action -eq 'build-run') { Invoke-Build -Target $Target }
        if ($action -eq 'run' -or $action -eq 'build-run') { Invoke-Run -DoReset $doReset }
        if (-not $Interactive) { return }
        switch (Select-Choice 'What next?' @('Rebuild & run again', 'Reset config, rebuild & run again (fresh first-run wizard)', 'Quit')) {
            1 { $action = 'build-run'; $doReset = $false }
            2 { $action = 'build-run'; $doReset = $true }
            3 { return }
        }
    }
}

# -------------------------------------------------------------------- main ---
$script:Interactive = $false

if (-not $Action) {
    $script:Interactive = $true
    $target = if ($Local) { 'local' } elseif ($Prod) { 'prod' } else { 'prod' }
    $menuChoice = Select-Choice 'CMC desktop client (Windows) - what do you want to do?' @(
        'Install requirements only'
        'Build (dev)'
        'Build & run (dev)'
        'Run (without building)'
        'Run tests'
        'Build installer (NSIS/MSI, production server)'
        'Delete build folder'
    )
    switch ($menuChoice) {
        1 { $Action = 'install' }
        2 { $Action = 'build' }
        3 { $Action = 'build-run' }
        4 { $Action = 'run' }
        5 { $Action = 'test' }
        6 { $Action = 'installer' }
        7 { $Action = 'clean' }
    }
    if ($Action -in @('build', 'run', 'build-run')) {
        switch (Select-Choice 'Which server should the client use?' @('Production (https://nc.cloudmail.city/)', "Local test server ($LocalServerUrl)")) {
            1 { $target = 'prod' }
            2 { $target = 'local' }
        }
    }
    if ($Action -in @('run', 'build-run')) {
        $Reset = Confirm-Ask 'Reset client config first (shows the first-run wizard again)?' $false
    }
} else {
    $target = if ($Local) { 'local' } else { 'prod' }
}

switch ($Action) {
    'install'   { Install-Requirements }
    'test'      { Invoke-Test }
    'installer' { Invoke-Installer }
    'clean'     { Invoke-Clean }
    default     { Invoke-BuildRunLoop -InitialAction $Action -Target $target -InitialReset $Reset }
}
