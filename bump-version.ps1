# bump-version.ps1
#
# Run from PowerShell inside the mouser_shared repo root (same folder as
# setup.py):
#   .\bump-version.ps1                  # 0.1.1 -> 0.1.2
#   .\bump-version.ps1 -Version 0.2.0   # set an exact version
#
# Bumps mouser_lookup/version.py, turns "## Unreleased" in CHANGELOG.md
# into "## X.Y.Z - date", commits ALL current changes with it, and creates
# a matching annotated git tag (v0.1.2). When the tag reaches GitHub, CI
# checks it matches version.py and the changelog and publishes a GitHub
# release with that version's notes. It does NOT push - push from
# PyCharm or the command line afterwards. Either way the TAG must be
# pushed too: PyCharm's Push dialog only sends tags when its "Push tags"
# box is ticked, and plain `git push` never sends them. An unpushed tag
# is what made InvenTree's update fail with "pathspec 'v0.1.1' did not
# match" - the plugin asks GitHub for a release that isn't there.
#
# Why the tag matters: the InvenTree plugin (and OMG) install this
# package straight from GitHub. If they point at the bare repo URL, pip
# sees mouser-lookup "already installed from that URL" and skips it on
# every update, whatever the version number says. Pointing them at the
# tag (...mouser_shared.git@v0.1.2) changes the URL each release, which
# makes pip actually reinstall. After pushing (commit AND tag):
#   - inventree_omg_plugin: its build-and-bump.ps1 updates the @vX.Y.Z
#     pin in setup.py automatically from GitHub's tags
#   - OMG's requirements.txt (if it lists mouser-lookup): update by hand

param(
    [string]$Version,
    [switch]$Yes      # release even with nothing under "## Unreleased"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git isn't on PATH in this PowerShell window."
    exit 1
}

$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
$emDash = [string][char]0x2014
$changelogPath = Join-Path $root "CHANGELOG.md"
if (-not (Test-Path $changelogPath)) {
    Write-Error "CHANGELOG.md not found - run this from the mouser_shared repo root."
    exit 1
}
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

    # Changelog first: if it isn't ready, stop before changing anything.
    $changelog = [System.IO.File]::ReadAllText($changelogPath, $utf8)
    $nl = if ($changelog.Contains("`r`n")) { "`r`n" } else { "`n" }
    $heading = [regex]::Match($changelog, '(?m)^## Unreleased[ \t]*\r?$')
    if (-not $heading.Success) {
        Write-Error "CHANGELOG.md has no '## Unreleased' heading - add one with this release's notes under it."
        exit 1
    }
    $bodyStart = $heading.Index + $heading.Length
    $next = [regex]::Match($changelog.Substring($bodyStart), '(?m)^## ')
    $bodyEnd = if ($next.Success) { $bodyStart + $next.Index } else { $changelog.Length }
    $body = $changelog.Substring($bodyStart, $bodyEnd - $bodyStart).Trim()
    if (-not $body) {
        if (-not $Yes) {
            $answer = Read-Host "Nothing under '## Unreleased' in CHANGELOG.md. Release $tag without notes? (y/N)"
            if ($answer -notmatch '^[Yy]') { Write-Host "Stopped - nothing changed."; exit 1 }
        }
        $body = "- No notes."
    }
    $date = Get-Date -Format 'yyyy-MM-dd'
    $released = "## Unreleased$nl$nl## $newVersion $emDash $date$nl$nl$body$nl$nl"
    [System.IO.File]::WriteAllText($changelogPath, $changelog.Substring(0, $heading.Index) + $released + $changelog.Substring($bodyEnd), $utf8)

    $newContent = $content -replace 'MOUSER_LOOKUP_VERSION\s*=\s*[''"]\d+\.\d+\.\d+[''"]', "MOUSER_LOOKUP_VERSION = `"$newVersion`""
    # No BOM: a UTF-8 BOM at the top of a .py file is harmless to Python
    # but shows up as a spurious change in git diffs.
    [System.IO.File]::WriteAllText($versionPath, $newContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Version bumped: $oldVersion -> $newVersion"

    git add -A
    git commit -m "Release $tag" | Out-Host
    git tag -a $tag -m "Release $tag"
    Write-Host ""
    Write-Host "Committed and tagged $tag. Now push the commit AND the tag:" -ForegroundColor Green
    Write-Host "  PyCharm:  Git -> Push (Ctrl+Shift+K), tick 'Push tags' (bottom-left) before clicking Push"
    Write-Host "  Terminal: git push; git push origin $tag"
    Write-Host ""
    Write-Host "Check the tag reached GitHub (should print a line ending in refs/tags/$tag):"
    Write-Host "  git ls-remote --tags origin $tag"
    Write-Host ""
    Write-Host "Once the tag is on GitHub, the plugin's build-and-bump.ps1 moves its pin to $tag"
    Write-Host "automatically. OMG's requirements.txt (if it lists mouser-lookup) needs this by hand:"
    Write-Host "  mouser-lookup @ git+https://github.com/SXSLYDA/mouser_shared.git@$tag"
}
finally {
    Pop-Location
}
