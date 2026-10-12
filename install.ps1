# Installs (or removes) the Always-On Bookmarks Bar mod into a Zen profile.
#
#   .\install.ps1                      install into the profile Zen opens by default
#   .\install.ps1 -ProfileDir <dir>    install into a specific profile folder
#   .\install.ps1 -Uninstall           remove the mod again
#
# Also works without cloning the repo:
#   irm https://raw.githubusercontent.com/TheTrueFerret/zen-always-on-bookmarks-bar/main/install.ps1 | iex
[CmdletBinding()]
param(
  [string]$ProfileDir,
  [switch]$Uninstall
)

$CssUrl = 'https://raw.githubusercontent.com/TheTrueFerret/zen-always-on-bookmarks-bar/main/chrome.css'
$CssName = 'always-on-bookmarks-bar.css'
$ImportLine = "@import url(`"$CssName`");"
$PrefLine = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
# Write files as UTF-8 without a BOM (Windows PowerShell's -Encoding UTF8 adds one).
$Utf8 = New-Object System.Text.UTF8Encoding $false

# Returns the profile folder Zen opens by default for the given Zen data folder.
# The [Install...] section is what Zen actually uses; `Default=1` on a
# [Profile] section is only the fallback for older setups.
function Get-DefaultProfile([string]$Root) {
  $ini = Join-Path $Root 'profiles.ini'
  if (-not (Test-Path -LiteralPath $ini -PathType Leaf)) { return $null }

  $installDefault = $null
  $profiles = @()
  $current = $null
  foreach ($line in Get-Content -LiteralPath $ini) {
    $line = $line.Trim()
    if ($line -match '^\[(.+)\]$') {
      $current = @{ Section = $Matches[1] }
      if ($current.Section -like 'Profile*') { $profiles += $current }
    } elseif ($current -and $line -match '^([^=]+)=(.*)$') {
      $current[$Matches[1]] = $Matches[2]
      if ($current.Section -like 'Install*' -and $Matches[1] -eq 'Default' -and -not $installDefault) {
        $installDefault = $Matches[2]
      }
    }
  }

  $rel = $installDefault
  if (-not $rel) {
    $default = $profiles | Where-Object { $_['Default'] -eq '1' -and $_['Path'] } | Select-Object -First 1
    if ($default) { $rel = $default['Path'] }
  }
  if (-not $rel) { return $null }
  if ([System.IO.Path]::IsPathRooted($rel)) { return $rel }
  return Join-Path $Root $rel
}

function Install-Mod {
  if (-not $ProfileDir) {
    $roots = @()
    if ($env:APPDATA) { $roots += Join-Path $env:APPDATA 'zen' }
    if ($HOME) {
      $roots += Join-Path $HOME '.zen'
      $roots += Join-Path $HOME '.config/zen'
      $roots += Join-Path $HOME 'Library/Application Support/zen'
    }
    foreach ($root in $roots) {
      $ProfileDir = Get-DefaultProfile $root
      if ($ProfileDir) { break }
    }
    if (-not $ProfileDir) {
      throw "couldn't find a Zen profile; pass one with -ProfileDir <dir> (see about:support > Profile Folder)"
    }
  }
  if (-not (Test-Path -LiteralPath $ProfileDir -PathType Container)) {
    throw "profile folder does not exist: $ProfileDir"
  }

  $chrome = Join-Path $ProfileDir 'chrome'
  $userChrome = Join-Path $chrome 'userChrome.css'
  $userJs = Join-Path $ProfileDir 'user.js'

  if ($Uninstall) {
    Remove-Item -LiteralPath (Join-Path $chrome $CssName) -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $userChrome) {
      $kept = @(Get-Content -LiteralPath $userChrome | Where-Object { $_.Trim() -ne $ImportLine })
      [System.IO.File]::WriteAllLines($userChrome, [string[]]$kept, $Utf8)
    }
    Write-Host "Removed Always-On Bookmarks Bar from: $ProfileDir"
    Write-Host 'Restart Zen to apply.'
    return
  }

  New-Item -ItemType Directory -Force -Path $chrome | Out-Null

  # Use the local copy when run from a clone, otherwise download it.
  $localCss = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'chrome.css' }
  if ($localCss -and (Test-Path -LiteralPath $localCss -PathType Leaf)) {
    Copy-Item -LiteralPath $localCss -Destination (Join-Path $chrome $CssName) -Force
  } else {
    # Windows PowerShell 5.1 doesn't enable TLS 1.2 by default.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $css = (Invoke-WebRequest -UseBasicParsing -Uri $CssUrl).Content
    [System.IO.File]::WriteAllText((Join-Path $chrome $CssName), $css, $Utf8)
  }

  # @import has to come before any other rule, so prepend it.
  $existing = @()
  if (Test-Path -LiteralPath $userChrome) { $existing = @(Get-Content -LiteralPath $userChrome) }
  if (-not ($existing | Where-Object { $_.Trim() -eq $ImportLine })) {
    [System.IO.File]::WriteAllLines($userChrome, [string[]](@($ImportLine) + $existing), $Utf8)
  }

  # Zen only loads userChrome.css with this pref enabled.
  $prefs = ''
  if (Test-Path -LiteralPath $userJs) { $prefs = [System.IO.File]::ReadAllText($userJs) }
  if (-not $prefs.Contains('toolkit.legacyUserProfileCustomizations.stylesheets", true')) {
    if ($prefs -and -not $prefs.EndsWith("`n")) { $PrefLine = "`n$PrefLine" }
    [System.IO.File]::AppendAllText($userJs, "$PrefLine`n", $Utf8)
  }

  Write-Host "Installed Always-On Bookmarks Bar into: $ProfileDir"
  Write-Host 'Restart Zen to apply. Make sure the bookmarks toolbar is set to'
  Write-Host "'Always Show' (Ctrl+Shift+B, or right-click the top bar > Bookmarks Toolbar)."
}

# Report errors instead of using `exit`, which would close the window when
# the script is piped into `iex`.
try {
  Install-Mod
} catch {
  Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
}
