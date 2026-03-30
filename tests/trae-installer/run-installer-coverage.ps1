param(
    [string]$RuleOwner = 'gotocx',
    [string]$RuleRepo = 'superpowers',
    [string]$RuleRef = 'trae-pr947-test-support'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$installerPath = Join-Path $repoRoot '.trae\INSTALL.md'
$installerText = Get-Content -Path $installerPath -Raw

$upstreamRuleUrl = 'https://raw.githubusercontent.com/obra/superpowers/main/.trae/rules/superpowers.md'
$testRuleUrl = "https://raw.githubusercontent.com/$RuleOwner/$RuleRepo/refs/heads/$RuleRef/.trae/rules/superpowers.md"
$skillsRepoUrl = 'https://github.com/obra/superpowers-skills.git'
$skillsFixturePath = Join-Path $env:TEMP 'trae-installer-skills-fixture'

$requiredSnippets = @(
    $upstreamRuleUrl,
    $skillsRepoUrl,
    'Rename-Item -Path ".trae\skills\using-skills" -NewName "using-superpowers"',
    'throw "Unsafe to continue automatic cleanup."'
)

foreach ($snippet in $requiredSnippets) {
    if (-not $installerText.Contains($snippet)) {
        throw "Installer snippet missing: $snippet"
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-ScenarioRoot {
    param([string]$Name)

    $root = Join-Path $env:TEMP ('trae-installer-' + $Name + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root | Out-Null
    return $root
}

function Initialize-SkillsFixture {
    if (Test-Path $skillsFixturePath) {
        return
    }

    $cloneSucceeded = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $stdout = Join-Path $env:TEMP ('trae-skills-fixture-out-' + $attempt + '.txt')
        $stderr = Join-Path $env:TEMP ('trae-skills-fixture-err-' + $attempt + '.txt')
        $proc = Start-Process git -ArgumentList @('clone', '--depth', '1', $skillsRepoUrl, $skillsFixturePath) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if ($proc.ExitCode -eq 0) {
            $cloneSucceeded = $true
            break
        }

        if (Test-Path $skillsFixturePath) {
            Remove-Item -Recurse -Force $skillsFixturePath -ErrorAction SilentlyContinue
        }

        if ($attempt -lt 3) {
            Start-Sleep -Seconds 2
        }
    }

    Get-ChildItem -Path $env:TEMP -Filter 'trae-skills-fixture-*.txt' | Remove-Item -Force -ErrorAction SilentlyContinue

    if (-not $cloneSucceeded) {
        $stderrText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { '' }
        throw "skills fixture clone failed with exit code $($proc.ExitCode): $stderrText"
    }
}

function Invoke-TraeInstaller {
    param([string]$RuleUrl)

    if (-not (Test-Path '.trae\rules')) {
        New-Item -ItemType Directory -Force -Path '.trae\rules' | Out-Null
    }

    $unexpectedEntries = @()
    if (Test-Path '.trae') {
        $unexpectedEntries = Get-ChildItem -Path '.trae' -Force | Where-Object {
            if ($_.Name -in @('rules', 'skills') -or $_.Name -like 'temp_*' -or $_.Name -eq 'INSTALL.md') {
                return $false
            }

            -not ($_.PSIsContainer -and -not (Get-ChildItem -Path $_.FullName -Force | Select-Object -First 1))
        }
    }

    if ($unexpectedEntries.Count -gt 0) {
        throw ('Unsafe to continue automatic cleanup: ' + (($unexpectedEntries | Select-Object -ExpandProperty Name) -join ','))
    }

    Invoke-WebRequest -Uri $RuleUrl -OutFile '.trae\rules\superpowers.md'

    if (Test-Path '.superpowers_temp') {
        Remove-Item -Recurse -Force '.superpowers_temp' -ErrorAction SilentlyContinue
    }

    Copy-Item -Path $skillsFixturePath -Destination '.superpowers_temp' -Recurse -Force

    New-Item -ItemType Directory -Force -Path '.trae\skills' | Out-Null

    Get-ChildItem -Path '.superpowers_temp\skills' -Directory | Where-Object { $_.Name -notin @('tool', 'examples') } | ForEach-Object {
        $entryDir = $_.FullName
        if (Test-Path (Join-Path $entryDir 'SKILL.md')) {
            $destinationPath = Join-Path '.trae\skills' $_.Name
            if (Test-Path $destinationPath) { Remove-Item -Recurse -Force $destinationPath }
            Copy-Item -Path $entryDir -Destination '.trae\skills\' -Recurse -Force
        } else {
            Get-ChildItem -Path $entryDir -Directory | ForEach-Object {
                $destinationPath = Join-Path '.trae\skills' $_.Name
                if (Test-Path $destinationPath) { Remove-Item -Recurse -Force $destinationPath }
                Copy-Item -Path $_.FullName -Destination '.trae\skills\' -Recurse -Force
            }
        }
    }

    if (Test-Path '.trae\skills\using-skills') {
        if (Test-Path '.trae\skills\using-superpowers') {
            Remove-Item -Recurse -Force '.trae\skills\using-superpowers'
        }
        Rename-Item -Path '.trae\skills\using-skills' -NewName 'using-superpowers'
    }

    if (Test-Path '.superpowers_temp') {
        Remove-Item -Recurse -Force '.superpowers_temp' -ErrorAction SilentlyContinue
    }

    Get-ChildItem -Path '.trae' -Force | Where-Object { $_.Name -like 'temp_*' -or $_.Name -eq 'INSTALL.md' } | ForEach-Object {
        Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
    }
}

function Run-Scenario {
    param(
        [string]$Name,
        [scriptblock]$Setup,
        [scriptblock]$Verify
    )

    $root = New-ScenarioRoot -Name $Name
    Push-Location $root
    try {
        & $Setup
        $status = 'pass'
        $message = ''
        try {
            Invoke-TraeInstaller -RuleUrl $testRuleUrl
        } catch {
            $status = 'blocked'
            $message = $_.Exception.Message
        }
        & $Verify $status $message
        return [pscustomobject]@{
            Name = $Name
            Status = $status
            Message = $message
        }
    } finally {
        Pop-Location
    }
}

$results = @()

Initialize-SkillsFixture

$results += Run-Scenario -Name 'clean-init' -Setup {
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'pass') "clean-init should pass: $message"
    Assert-True (Test-Path '.trae\rules\superpowers.md') 'clean-init missing rule file'
    Assert-True (Test-Path '.trae\skills\using-superpowers') 'clean-init missing using-superpowers'
    Assert-True (-not (Test-Path '.superpowers_temp')) 'clean-init left temp clone'
}

$results += Run-Scenario -Name 'existing-project' -Setup {
    New-Item -ItemType Directory -Path 'src' -Force | Out-Null
    Set-Content 'src\app.txt' 'project-data'
    Set-Content 'README.md' 'my-project'
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'pass') "existing-project should pass: $message"
    Assert-True (Test-Path 'src\app.txt') 'existing-project should preserve src content'
    Assert-True (Test-Path 'README.md') 'existing-project should preserve README'
    Assert-True (Test-Path '.trae\skills\using-superpowers') 'existing-project missing using-superpowers'
}

$results += Run-Scenario -Name 'custom-rule-preserved' -Setup {
    New-Item -ItemType Directory -Path '.trae\rules' -Force | Out-Null
    Set-Content '.trae\rules\custom.md' 'keep-rule'
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'pass') "custom-rule-preserved should pass: $message"
    Assert-True (Test-Path '.trae\rules\custom.md') 'custom-rule-preserved should keep custom.md'
    Assert-True (Test-Path '.trae\rules\superpowers.md') 'custom-rule-preserved missing superpowers.md'
}

$results += Run-Scenario -Name 'custom-skill-preserved' -Setup {
    New-Item -ItemType Directory -Path '.trae\skills\my-skill' -Force | Out-Null
    Set-Content '.trae\skills\my-skill\SKILL.md' 'custom-skill'
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'pass') "custom-skill-preserved should pass: $message"
    Assert-True (Test-Path '.trae\skills\my-skill\SKILL.md') 'custom-skill-preserved should keep custom skill'
    Assert-True (Test-Path '.trae\skills\using-superpowers') 'custom-skill-preserved missing using-superpowers'
}

$results += Run-Scenario -Name 'conflicting-skill-replaced' -Setup {
    New-Item -ItemType Directory -Path '.trae\skills\brainstorming' -Force | Out-Null
    Set-Content '.trae\skills\brainstorming\SKILL.md' 'custom-brainstorming'
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'pass') "conflicting-skill-replaced should pass: $message"
    $firstLine = Get-Content '.trae\skills\brainstorming\SKILL.md' -TotalCount 1
    Assert-True ($firstLine -ne 'custom-brainstorming') 'conflicting-skill-replaced should replace the conflicting skill'
}

$results += Run-Scenario -Name 'unexpected-file-blocked' -Setup {
    New-Item -ItemType Directory -Path '.trae' -Force | Out-Null
    Set-Content '.trae\notes.txt' 'manual-review'
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'blocked') 'unexpected-file-blocked should block'
    Assert-True (Test-Path '.trae\notes.txt') 'unexpected-file-blocked should leave notes.txt untouched'
}

$results += Run-Scenario -Name 'unexpected-nonempty-dir-blocked' -Setup {
    New-Item -ItemType Directory -Path '.trae\manual-review' -Force | Out-Null
    Set-Content '.trae\manual-review\keep.txt' 'manual-review'
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'blocked') 'unexpected-nonempty-dir-blocked should block'
    Assert-True (Test-Path '.trae\manual-review\keep.txt') 'unexpected-nonempty-dir-blocked should leave keep.txt untouched'
}

$results += Run-Scenario -Name 'empty-dir-tolerated' -Setup {
    New-Item -ItemType Directory -Path '.trae\empty-folder' -Force | Out-Null
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'pass') "empty-dir-tolerated should pass: $message"
    Assert-True (Test-Path '.trae\empty-folder') 'empty-dir-tolerated should leave empty folder untouched'
}

$results += Run-Scenario -Name 'rerun-idempotent' -Setup {
    Invoke-TraeInstaller -RuleUrl $testRuleUrl
} -Verify {
    param($status, $message)
    Assert-True ($status -eq 'pass') "rerun-idempotent should pass: $message"
    Assert-True (Test-Path '.trae\rules\superpowers.md') 'rerun-idempotent missing rule file'
    Assert-True (Test-Path '.trae\skills\using-superpowers') 'rerun-idempotent missing using-superpowers'
    Assert-True (-not (Test-Path '.superpowers_temp')) 'rerun-idempotent left temp clone'
}

Write-Output "Installer path: $installerPath"
Write-Output "Runtime rule URL: $testRuleUrl"
Write-Output ''
$results | Format-Table -AutoSize
