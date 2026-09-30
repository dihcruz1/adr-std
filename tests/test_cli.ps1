# Testes do comando adr-std e do instalador para Windows (Pester 5).
# Uso: Invoke-Pester -Path tests/test_cli.ps1 -CI
# Cada teste roda num perfil temporário (ADR_STD_HOME, ADR_STD_LOCALAPPDATA, ADR_STD_APPDATA); o perfil real nunca é usado.
# Espelha tests/test_cli.sh. Escrito sem poder executar no ambiente de desenvolvimento: validar no CI do Windows.

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    $script:Cli = Join-Path $Root 'bin/adr-std.ps1'
    $script:Installer = Join-Path $Root 'install.ps1'
    $script:Ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

    function Invoke-Cli {
        param([string[]]$CliArgs, [string]$Answer = $null)
        if ($null -ne $Answer) { $env:ADR_STD_ANSWER = $Answer } else { Remove-Item Env:ADR_STD_ANSWER -ErrorAction SilentlyContinue }
        $out = & $script:Ps -NoProfile -ExecutionPolicy Bypass -File $script:Cli @CliArgs 2>&1 | Out-String
        [pscustomobject]@{ Output = $out; Code = $LASTEXITCODE }
    }

    function Invoke-Installer {
        param([string[]]$InstallerArgs, [string]$Answer = 'n')
        $env:ADR_STD_ANSWER = $Answer
        $out = & $script:Ps -NoProfile -ExecutionPolicy Bypass -File $script:Installer @InstallerArgs 2>&1 | Out-String
        [pscustomobject]@{ Output = $out; Code = $LASTEXITCODE }
    }
}

BeforeEach {
    $script:Tmp = Join-Path ([IO.Path]::GetTempPath()) ("adrstd-test-" + [Guid]::NewGuid().ToString('N'))
    $script:Home = Join-Path $Tmp 'home'
    New-Item -ItemType Directory -Force -Path $Home, (Join-Path $Tmp 'local'), (Join-Path $Tmp 'roam') | Out-Null
    $env:ADR_STD_HOME = $Home
    $env:ADR_STD_LOCALAPPDATA = Join-Path $Tmp 'local'
    $env:ADR_STD_APPDATA = Join-Path $Tmp 'roam'
    $env:ADR_STD_NO_PATH = '1'
    $script:State = Join-Path $Tmp 'roam/adr-std/state'
}

AfterEach {
    Remove-Item Env:ADR_STD_HOME, Env:ADR_STD_LOCALAPPDATA, Env:ADR_STD_APPDATA, Env:ADR_STD_NO_PATH, Env:ADR_STD_ANSWER -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Tmp
}

Describe 'agents.tsv' {
    It 'tem 15 agentes válidos com 5 colunas e ids únicos' {
        $rows = Get-Content (Join-Path $Root 'agents.tsv') | Where-Object { $_ -and -not $_.StartsWith('#') }
        $rows.Count | Should -Be 15
        foreach ($r in $rows) { ($r -split "`t").Count | Should -Be 5 }
        ($rows | ForEach-Object { ($_ -split "`t")[0] } | Sort-Object -Unique).Count | Should -Be 15
    }
}

Describe 'version, help e agents' {
    It 'version mostra a versão do arquivo VERSION' {
        $r = Invoke-Cli @('version')
        $r.Code | Should -Be 0
        $r.Output | Should -Match ((Get-Content -Raw (Join-Path $Root 'VERSION')).Trim())
    }
    It 'help lista os comandos e comando inválido falha' {
        $r = Invoke-Cli @('help')
        foreach ($c in 'install', 'update', 'uninstall', 'self-uninstall', 'status', 'agents', 'check', 'version') { $r.Output | Should -Match $c }
        (Invoke-Cli @('comando-inexistente')).Code | Should -Be 2
    }
    It 'agents marca os agentes encontrados' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude'), (Join-Path $Home '.codex') | Out-Null
        $r = Invoke-Cli @('agents')
        ($r.Output -split "`n" | Where-Object { $_ -match '^\s*claude-code' }) | Should -Match 'encontrado'
        ($r.Output -split "`n" | Where-Object { $_ -match '^\s*cursor' }) | Should -Not -Match 'encontrado'
    }
}

Describe 'install' {
    It 'instala só nos agentes indicados, com marcador e estado' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude'), (Join-Path $Home '.codex') | Out-Null
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $Home '.claude/skills/adr-std/.installed-by-adr-std') | Should -BeTrue
        Test-Path (Join-Path $Home '.codex/skills/adr-std') | Should -BeFalse
        (Get-Content $State) -match "^agent`tclaude-code`t" | Should -Not -BeNullOrEmpty
    }
    It 'aceita --agent com vírgula e com espaço' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude'), (Join-Path $Home '.codex') | Out-Null
        (Invoke-Cli @('install', '--agent', 'claude-code,codex')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.codex/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It 'não duplica na pasta compartilhada' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.gemini'), (Join-Path $Home '.config/opencode') | Out-Null
        (Invoke-Cli @('install', 'gemini-cli', 'opencode')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.agents/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $Home '.gemini/skills/adr-std') | Should -BeFalse
    }
    It 'dry-run não altera nada' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude') | Out-Null
        (Invoke-Cli @('install', '--dry-run', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.claude/skills/adr-std') | Should -BeFalse
        Test-Path $State | Should -BeFalse
    }
    It 'nome de agente errado sugere o mais próximo' {
        $r = Invoke-Cli @('install', 'claude')
        $r.Code | Should -Not -Be 0
        $r.Output | Should -Match 'quis dizer claude-code'
    }
    It 'menu instala os agentes escolhidos' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude'), (Join-Path $Home '.codex') | Out-Null
        (Invoke-Cli @('install') -Answer '1 2').Code | Should -Be 0
        Test-Path (Join-Path $Home '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $Home '.codex/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It '--all instala em todos os encontrados' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude'), (Join-Path $Home '.gemini') | Out-Null
        (Invoke-Cli @('install', '--all')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $Home '.agents/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $Home '.codex/skills/adr-std') | Should -BeFalse
    }
    It 'sem terminal e sem agentes falha com código 3' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude') | Out-Null
        Remove-Item Env:ADR_STD_ANSWER -ErrorAction SilentlyContinue
        $r = Invoke-Cli @('install')
        $r.Code | Should -Be 3
        $r.Output | Should -Match '--agent'
    }
    It 'não sobrescreve pasta que não instalou (código 4)' {
        $dest = Join-Path $Home '.claude/skills/adr-std'
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Set-Content -Path (Join-Path $dest 'nota.txt') -Value 'do usuário'
        $r = Invoke-Cli @('install', 'claude-code')
        $r.Code | Should -Be 4
        (Get-Content (Join-Path $dest 'nota.txt')) | Should -Be 'do usuário'
        Test-Path (Join-Path $dest 'SKILL.md') | Should -BeFalse
    }
    It 'é idempotente e substitui o que instalou' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude') | Out-Null
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        Set-Content -Path (Join-Path $Home '.claude/skills/adr-std/residuo.txt') -Value 'antigo'
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.claude/skills/adr-std/residuo.txt') | Should -BeFalse
        @(Get-Content $State | Where-Object { $_ -match "^agent`tclaude-code`t" }).Count | Should -Be 1
    }
}

Describe 'uninstall e status' {
    It 'remove só o agente indicado' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude'), (Join-Path $Home '.codex') | Out-Null
        Invoke-Cli @('install', 'claude-code', 'codex') | Out-Null
        (Invoke-Cli @('uninstall', 'codex')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.codex/skills/adr-std') | Should -BeFalse
        Test-Path (Join-Path $Home '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It 'remove todos os registrados e preserva pastas do usuário' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude') | Out-Null
        Invoke-Cli @('install', 'claude-code') | Out-Null
        $mine = Join-Path $Home '.codex/skills/adr-std'
        New-Item -ItemType Directory -Force -Path $mine | Out-Null
        Set-Content -Path (Join-Path $mine 'meu.txt') -Value 'x'
        (Invoke-Cli @('uninstall')).Code | Should -Be 0
        Test-Path (Join-Path $Home '.claude/skills/adr-std') | Should -BeFalse
        Test-Path (Join-Path $mine 'meu.txt') | Should -BeTrue
    }
    It 'status mostra "não instalada", a versão e pasta ausente como danificada' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude'), (Join-Path $Home '.codex') | Out-Null
        (Invoke-Cli @('status')).Output | Should -Match 'não instalada'
        Invoke-Cli @('install', 'claude-code', 'codex') | Out-Null
        (Invoke-Cli @('status')).Output | Should -Match 'claude-code'
        Remove-Item -Recurse -Force (Join-Path $Home '.codex/skills/adr-std')
        ((Invoke-Cli @('status')).Output -split "`n" | Where-Object { $_ -match 'codex' }) | Should -Match 'danificada'
    }
}

Describe 'check' {
    It 'passa na fixture e falha no template (precisa de Python 3)' -Skip:(-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
        (Invoke-Cli @('check', (Join-Path $Root 'tests/fixtures/0001-cache-de-sessao-em-redis.md'))).Code | Should -Be 0
        (Invoke-Cli @('check', (Join-Path $Root 'skill/references/template-madr.md'))).Code | Should -Not -Be 0
    }
}

Describe 'instalador e self-uninstall' {
    It 'instala o comando, a fonte e a skill (modo local)' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude') | Out-Null
        $r = Invoke-Installer @('--agent', 'claude-code')
        $r.Code | Should -Be 0
        Test-Path (Join-Path $Tmp 'local/adr-std/bin/adr-std.ps1') | Should -BeTrue
        Test-Path (Join-Path $Tmp 'local/adr-std/bin/adr-std.cmd') | Should -BeTrue
        Test-Path (Join-Path $Tmp 'local/adr-std/skill/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $Home '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It 'self-uninstall remove skill, estado e comando' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Home '.claude') | Out-Null
        Invoke-Installer @('--agent', 'claude-code') | Out-Null
        $installed = Join-Path $Tmp 'local/adr-std/bin/adr-std.ps1'
        & $script:Ps -NoProfile -ExecutionPolicy Bypass -File $installed self-uninstall | Out-Null
        Test-Path (Join-Path $Home '.claude/skills/adr-std') | Should -BeFalse
        Test-Path (Join-Path $Tmp 'roam/adr-std') | Should -BeFalse
        Test-Path (Join-Path $Tmp 'local/adr-std/skill') | Should -BeFalse
        Test-Path (Join-Path $Tmp 'local/adr-std/bin/adr-std.cmd') | Should -BeFalse
    }
}
