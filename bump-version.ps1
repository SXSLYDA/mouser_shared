# bump-version.ps1
#
# Run from PowerShell inside the mouser_shared repo root (same folder as
# setup.py):
#   .\bump-version.ps1                  # 0.1.1 -> 0.1.2
#   .\bump-version.ps1 -Version 0.2.0   # set an exact version
#
# Bumps mouser_lookup/version.py, commits ALL current changes with it,
# and creates a matching git tag (v0.1.2). It does NOT push - it prints
# the commands so you can review first.
#
# Why the tag matters: the InvenTree plugin (and OMG) install this
# package straight from GitHub. If they point at the bare repo URL, pip
# sees mouser-lookup "already installed from that URL" and skips it on
# every update, whatever the version number says. Pointing them at the
# tag (...mouser_shared.git@v0.1.2) changes the URL each release, which
# makes pip actually reinstall. So after pushing, update the @vX.Y.Z in:
#   - inventree_omg_plugin/setup.py   (install_requires)
#   - OMG's requirements.txt          (if it lists mouser-lookup)

param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git isn't on PATH in this PowerShell window."
    exit 1
}

$root = $PSScriptRoot
$versionPath = Join-Path $root "mouser_lookup\version.py"
if (-not (Test-Path $versionPath)) {
    Write-Error "mouser_lookup\version.py not found - run this from the mouser_shared repo root."
    exit 1
}

$content = Get-Content $versionPath -Raw
$match = [regex]::Match($content, 'MOUSER_LOOKUP_VERSION\s*=\s*[''"](\d+)\.(\d+)\.(\d+)[''"]')
if (-not $match.Success) {
    Write-Error "Couldn't find MOUSER_LOOKUP_VERSION = `"X.Y.Z`" in version.py."
    exit 1
}
$oldVersion = "$($match.Groups[1].Value).$($match.Groups[2].Value).$($match.Groups[3].Value)"

if ($Version) {
    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        Write-Error "-Version must look like 1.2.3"
        exit 1
    }
    $newVersion = $Version
} else {
    $patch = [int]$match.Groups[3].Value + 1
    $newVersion = "$($match.Groups[1].Value).$($match.Groups[2].Value).$patch"
}
$tag = "v$newVersion"

Push-Location $root
try {
    if (git tag --list $tag) {
        Write-Error "Tag $tag already exists - pick a different version (-Version)."
        exit 1
    }

    $newContent = $content -replace 'MOUSER_LOOKUP_VERSION\s*=\s*[''"]\d+\.\d+\.\d+[''"]', "MOUSER_LOOKUP_VERSION = `"$newVersion`""
    # No BOM: a UTF-8 BOM at the top of a .py file is harmless to Python
    # but shows up as a spurious change in git diffs.
    [System.IO.File]::WriteAllText($versionPath, $newContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Version bumped: $oldVersion -> $newVersion"

    git add -A
    git commit -m "Release $tag" | Out-Host
    git tag $tag
    Write-Host ""
    Write-Host "Committed and tagged $tag. Review with 'git show --stat', then push BOTH:"
    Write-Host "  git push"
    Write-Host "  git push origin $tag"
    Write-Host ""
    Write-Host "Then point the plugin (and OMG, if it uses it) at this release:"
    Write-Host "  mouser-lookup @ git+https://github.com/SXSLYDA/mouser_shared.git@$tag"
}
finally {
    Pop-Location
}
