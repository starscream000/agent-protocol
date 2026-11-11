# Installs or updates the agent protocol in the current project (Windows).
#
# Run it in PowerShell from the top folder of a git repository:
#
#   irm https://raw.githubusercontent.com/starscream000/agent-protocol/main/install.ps1 | iex
#
# or, from a local copy of agent-protocol:
#
#   C:\path\to\agent-protocol\install.ps1
#
# Protocol-owned files (.agents\) are overwritten with the newest version.
# Project-owned files (CLAUDE.md, docs\, tasks\, reports\) are created only
# if they are missing. Nothing is committed; review the changes and commit
# them yourself.
#
# Works in Windows PowerShell 5.1 and PowerShell 7.

function Install-AgentProtocol {
    param([string]$ScriptFolder)

    $Repo   = 'starscream000/agent-protocol'
    $Branch = 'main'
    $Marker = '<!-- agent-protocol:start -->'
    $Utf8   = New-Object System.Text.UTF8Encoding($false)

    function Fail([string]$Message) {
        Write-Host "Error: $Message" -ForegroundColor Red
    }

    function Same-Path([string]$A, [string]$B) {
        $a2 = [System.IO.Path]::GetFullPath($A).TrimEnd('\', '/')
        $b2 = [System.IO.Path]::GetFullPath($B).TrimEnd('\', '/')
        return [string]::Equals($a2, $b2, [System.StringComparison]::OrdinalIgnoreCase)
    }

    # --- Where are we installing? -------------------------------------------

    $Target = (Get-Location).ProviderPath

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Fail 'git is not installed or not on the PATH. Install Git for Windows first.'
        return
    }

    $Top = $null
    try { $Top = (& git -C $Target rev-parse --show-toplevel 2>$null) } catch { $Top = $null }
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Top)) {
        Fail "this folder is not inside a git repository. Run 'git init' first."
        return
    }
    $Top = ([string]$Top).Trim()
    if (-not (Same-Path $Top $Target)) {
        Fail "run this from the top folder of the repository: $Top"
        return
    }

    # --- Where do the protocol files come from? -----------------------------

    $Src = $null
    $Tmp = $null

    if ($ScriptFolder -and
        (Test-Path (Join-Path $ScriptFolder 'scaffold')) -and
        (Test-Path (Join-Path $ScriptFolder '.agents/PROTOCOL.md'))) {
        $Src = $ScriptFolder
    }

    try {
        if (-not $Src) {
            $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-protocol-" + [System.Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $Tmp -Force | Out-Null
            $Zip = Join-Path $Tmp 'protocol.zip'

            Write-Host "Downloading agent-protocol ($Branch)..."
            $oldProgress = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                [Net.ServicePointManager]::SecurityProtocol =
                    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            } catch { }
            try {
                Invoke-WebRequest -UseBasicParsing `
                    -Uri "https://github.com/$Repo/archive/refs/heads/$Branch.zip" `
                    -OutFile $Zip
                Expand-Archive -Path $Zip -DestinationPath $Tmp -Force
            } catch {
                Fail "download failed. Check your connection and try again. ($($_.Exception.Message))"
                return
            } finally {
                $ProgressPreference = $oldProgress
            }

            $Unpacked = Get-ChildItem -Path $Tmp -Directory | Select-Object -First 1
            if (-not $Unpacked) {
                Fail 'the downloaded protocol could not be unpacked.'
                return
            }
            $Src = $Unpacked.FullName
        }

        if (Same-Path $Src $Target) {
            Fail 'this is the agent-protocol repository itself. Run the script inside the project you want to set up.'
            return
        }
        if (-not (Test-Path (Join-Path $Src '.agents/VERSION'))) {
            Fail "the protocol source looks incomplete: $Src"
            return
        }

        $NewVersion = ([System.IO.File]::ReadAllText((Join-Path $Src '.agents/VERSION'))).Trim()
        $OldVersion = 'none'
        $OldVersionFile = Join-Path $Target '.agents/VERSION'
        if (Test-Path $OldVersionFile) {
            $OldVersion = ([System.IO.File]::ReadAllText($OldVersionFile)).Trim()
        }

        # --- Protocol-owned files: always replaced --------------------------

        $AgentsDir    = Join-Path $Target '.agents'
        $TemplatesDir = Join-Path $AgentsDir 'templates'
        if (Test-Path $TemplatesDir) { Remove-Item -Recurse -Force $TemplatesDir }
        New-Item -ItemType Directory -Path $TemplatesDir -Force | Out-Null

        Copy-Item -Force (Join-Path $Src '.agents/PROTOCOL.md') (Join-Path $AgentsDir 'PROTOCOL.md')
        Copy-Item -Force (Join-Path $Src '.agents/VERSION')     (Join-Path $AgentsDir 'VERSION')
        Get-ChildItem -File -Path (Join-Path $Src '.agents/templates') | ForEach-Object {
            Copy-Item -Force $_.FullName (Join-Path $TemplatesDir $_.Name)
        }

        # --- Project-owned files: created only if missing -------------------

        $Created = New-Object System.Collections.Generic.List[string]
        $Kept    = New-Object System.Collections.Generic.List[string]

        $ScaffoldRoot = [System.IO.Path]::GetFullPath((Join-Path $Src 'scaffold')).TrimEnd('\', '/')
        $ScaffoldFiles = Get-ChildItem -File -Recurse -Force -Path $ScaffoldRoot | Sort-Object FullName

        foreach ($File in $ScaffoldFiles) {
            $Rel     = $File.FullName.Substring($ScaffoldRoot.Length).TrimStart('\', '/')
            $RelShow = $Rel -replace '\\', '/'
            $Dest    = Join-Path $Target $Rel
            $DestDir = Split-Path -Parent $Dest

            if ($File.Name -eq '.gitkeep') {
                # A placeholder so git keeps an empty folder. Skip if the
                # folder already exists.
                if (-not (Test-Path $DestDir)) {
                    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
                    Copy-Item -Force $File.FullName $Dest
                    $Created.Add(((Split-Path -Parent $RelShow) -replace '\\', '/') + '/')
                }
                continue
            }

            if (Test-Path $Dest) {
                $Kept.Add($RelShow)
            } else {
                if (-not (Test-Path $DestDir)) {
                    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
                }
                Copy-Item -Force $File.FullName $Dest
                $Created.Add($RelShow)
            }
        }

        # --- Existing CLAUDE.md: add the pointer to the protocol once -------

        $ClaudeNote = ''
        $ClaudeFile = Join-Path $Target 'CLAUDE.md'
        if (Test-Path $ClaudeFile) {
            $Existing = [System.IO.File]::ReadAllText($ClaudeFile)
            if (-not $Existing.Contains($Marker)) {
                $Template = [System.IO.File]::ReadAllText((Join-Path $Src 'scaffold/CLAUDE.md'))
                $Start = $Template.IndexOf($Marker)
                $EndMarker = '<!-- agent-protocol:end -->'
                $End = $Template.IndexOf($EndMarker)
                if ($Start -ge 0 -and $End -gt $Start) {
                    $Block = $Template.Substring($Start, $End + $EndMarker.Length - $Start)
                    $Separator = "`n"
                    if (-not $Existing.EndsWith("`n")) { $Separator = "`n`n" }
                    [System.IO.File]::AppendAllText($ClaudeFile, $Separator + $Block + "`n", $Utf8)
                    $ClaudeNote = 'Added the protocol pointer to the end of your existing CLAUDE.md.'
                }
            }
        }

        # --- Summary --------------------------------------------------------

        Write-Host ''
        if ($OldVersion -eq 'none') {
            Write-Host "Agent protocol $NewVersion installed."
        } elseif ($OldVersion -eq $NewVersion) {
            Write-Host "Agent protocol $NewVersion re-installed (already on this version)."
        } else {
            Write-Host "Agent protocol updated: $OldVersion -> $NewVersion."
        }

        Write-Host ''
        Write-Host 'Replaced (protocol-owned):'
        Write-Host '  .agents/PROTOCOL.md'
        Write-Host '  .agents/VERSION'
        Write-Host '  .agents/templates/'

        if ($Created.Count -gt 0) {
            Write-Host ''
            Write-Host 'Created (yours to edit):'
            foreach ($Item in $Created) { Write-Host "  $Item" }
        }

        if ($Kept.Count -gt 0) {
            Write-Host ''
            Write-Host 'Left untouched (already existed):'
            foreach ($Item in $Kept) { Write-Host "  $Item" }
        }

        if ($ClaudeNote) {
            Write-Host ''
            Write-Host $ClaudeNote
        }

        Write-Host ''
        Write-Host "Nothing was committed. Review with 'git status', then commit with:"
        Write-Host '  git add -A'
        Write-Host "  git commit -m `"protocol: install v$NewVersion`""
    }
    finally {
        if ($Tmp -and (Test-Path $Tmp)) {
            Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
        }
    }
}

Install-AgentProtocol -ScriptFolder $PSScriptRoot
