# --- Change CWD ---
$cwd_orig = Get-Location
$cwd_dir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$cwd_dirname = Split-Path -Path $cwd_dir -Leaf
if ($cwd_dirname -ieq "scripts") {
    Set-Location (Split-Path $cwd_dir -Parent)
}

# --- PowerShell 7+ Required ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "PowerShell 7+ is required. Attempting to relaunch..."

    # Try to find pwsh in PATH
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue

    # If not found in PATH, try known locations
    if (-not $pwsh) {
        $knownPaths = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "$env:ProgramFiles(x86)\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe"
        )
        $pwsh = $knownPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    } else {
        $pwsh = $pwsh.Source
    }
    if ($pwsh) {
        Write-Host "Relaunching script in PowerShell 7..."
        Start-Process -FilePath $pwsh -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$($MyInvocation.MyCommand.Definition)`""
        $failed = $false
    } else {
        Write-Host "PowerShell 7 not found in PATH or common locations."
        Write-Host "Download it here: https://aka.ms/powershell"
        $failed = $true
    }

    Write-Host "`nFor a better script experience, install PowerShell 7+ and ensure your code editor is configured to use it."
    Write-Host "Download PowerShell 7+: https://aka.ms/powershell"
    Write-Host "Configure Rider to use PowerShell 7+: https://blog.ironmansoftware.com/daily-powershell/powershell-jetbrains-rider/`n"
    Write-Host "Configure Visual Studio to use PowerShell 7+: https://stackoverflow.com/a/76045797/6472449`n"
    Write-Host "Configure Visual Studio Code to use PowerShell 7+: https://stackoverflow.com/a/73846532/6472449`n"

    if ($failed) {
        exit 1
    } else {
        exit 0
    }
}
Write-Host "Using PowerShell version: $($PSVersionTable.PSVersion)`n" -ForegroundColor DarkGray


# --- Find the Factorio directory ---
function Get-FactorioModsPath {
    # Detect platform
    $results = @()

    if ($IsWindows) {
        # Standard install
        $winAppData = [Environment]::GetFolderPath('ApplicationData')
        $results += Join-Path $winAppData "Factorio\mods"

        # Steam cloud (may not have mods, but list it)
        $userProfile = [Environment]::GetFolderPath('UserProfile')
        $steamUserData = Join-Path $userProfile "AppData\Local\Steam\userdata"
        if (Test-Path $steamUserData) {
            $userDirs = Get-ChildItem $steamUserData -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $userDirs) {
                $remote = Join-Path $dir.FullName "427520\remote"
                if (Test-Path $remote) { $results += $remote }
            }
        }
    }
    elseif ($IsMacOS) {
        # Standard install
        $results += "$HOME/Library/Application Support/factorio/mods"

        # Steam
        $steamUserData = "$HOME/Library/Application Support/Steam/userdata"
        if (Test-Path $steamUserData) {
            $userDirs = Get-ChildItem $steamUserData -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $userDirs) {
                $remote = "$($dir.FullName)/427520/remote"
                if (Test-Path $remote) { $results += $remote }
            }
        }
    }
    elseif ($IsLinux) {
        # Standard install
        $results += "$HOME/.factorio/mods"

        # Flatpak Steam
        $flatpakSteam = "$HOME/.var/app/com.valvesoftware.Steam"
        if (Test-Path $flatpakSteam) {
            $results += "$flatpakSteam/.factorio/mods"
            $steamUserData = "$flatpakSteam/Steam/userdata"
            if (Test-Path $steamUserData) {
                $userDirs = Get-ChildItem $steamUserData -Directory -ErrorAction SilentlyContinue
                foreach ($dir in $userDirs) {
                    $remote = "$($dir.FullName)/427520/remote"
                    if (Test-Path $remote) { $results += $remote }
                }
            }
        }
        # Native Steam (non-Flatpak)
        $steamUserData = "$HOME/.steam/steam/userdata"
        if (Test-Path $steamUserData) {
            $userDirs = Get-ChildItem $steamUserData -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $userDirs) {
                $remote = "$($dir.FullName)/427520/remote"
                if (Test-Path $remote) { $results += $remote }
            }
        }
    }

    # Filter to only existing paths
    $results | Where-Object { Test-Path $_ } | Sort-Object -Unique
}
Write-Host "Searching for Factorio 'mods' directories..." -ForegroundColor Cyan
$paths = Get-FactorioModsPath
if ($paths.Count -eq 0) {
    Write-Host "No Factorio mods directories found on this system." -ForegroundColor Red
    return
} else {
    Write-Host "`nFound the following Factorio mods directories:" -ForegroundColor Cyan
    Write-Host $paths[0] -ForegroundColor Yellow
}
$factorio = $paths[0]


# --- Parse the info JSON ---
$infopath = Join-Path (Resolve-Path ".") "src/info.json"
if (-not (Test-Path $infopath)) {
    Write-Host "No info.json found in the src directory." -ForegroundColor Red
    return
}
$info = Get-Content $infopath | ConvertFrom-Json
$modname = $info.name
Write-Host "`nParsed mod name:" -ForegroundColor Cyan
Write-Host $modname -ForegroundColor Yellow

# --- Create a symbolic link to the Factorio mods directory ---
$source = Join-Path (Resolve-Path ".") "src"
$target = Join-Path $factorio $modname
Write-Host "`nSource directory:" -ForegroundColor Cyan
Write-Host $source -ForegroundColor Yellow
Write-Host "`nTarget directory:" -ForegroundColor Cyan
Write-Host $target -ForegroundColor Yellow
Write-Host ""
if (Test-Path $target) {
    Write-Host "Removing existing symbolic link..." -ForegroundColor Cyan
    Remove-Item $target -Force -ErrorAction SilentlyContinue
}
Write-Host "Creating symbolic link..." -ForegroundColor Cyan
New-Item -ItemType SymbolicLink -Path $target -Target $source -Force -ErrorAction Stop | Out-Null
Write-Host "Done." -ForegroundColor Yellow

# --- Restore original CWD ---
Set-Location $cwd_orig
