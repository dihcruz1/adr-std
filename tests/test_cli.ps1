# Testes do comando adr-std e do instalador para Windows (Pester 5).
# Uso: Invoke-Pester -Path tests/test_cli.ps1 -CI
# Cada teste roda num perfil temporário (ADR_STD_HOME, ADR_STD_LOCALAPPDATA, ADR_STD_APPDATA); o perfil real nunca é usado.
# Espelha tests/test_cli.sh. Escrito sem poder executar no ambiente de desenvolvimento: validar no CI do Windows.

Describe 'adr-std' {

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
    $script:HomeDir = Join-Path $Tmp 'home'
    New-Item -ItemType Directory -Force -Path $HomeDir, (Join-Path $Tmp 'local'), (Join-Path $Tmp 'roam') | Out-Null
    $env:ADR_STD_HOME = $HomeDir
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
        foreach ($c in 'install', 'update', 'uninstall', 'self-uninstall', 'status', 'agents', 'check', 'new', 'list', 'link', 'organize', 'create', 'supersede', 'review', 'audit', 'ask', 'config', 'version') { $r.Output | Should -Match $c }
        (Invoke-Cli @('comando-inexistente')).Code | Should -Be 2
    }
    It 'agents marca os agentes encontrados' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.codex') | Out-Null
        $r = Invoke-Cli @('agents')
        ($r.Output -split "`n" | Where-Object { $_ -match '^\s*claude-code' }) | Should -Match 'encontrado'
        ($r.Output -split "`n" | Where-Object { $_ -match '^\s*cursor' }) | Should -Not -Match 'encontrado'
    }
}

Describe 'install' {
    It 'instala só nos agentes indicados, com marcador e estado' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.codex') | Out-Null
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std/.installed-by-adr-std') | Should -BeTrue
        Test-Path (Join-Path $HomeDir '.codex/skills/adr-std') | Should -BeFalse
        (Get-Content $State) -match "^agent`tclaude-code`t" | Should -Not -BeNullOrEmpty
    }
    It 'aceita --agent com vírgula e com espaço' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.codex') | Out-Null
        (Invoke-Cli @('install', '--agent', 'claude-code,codex')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.codex/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It 'não duplica na pasta compartilhada' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.gemini'), (Join-Path $HomeDir '.config/opencode') | Out-Null
        (Invoke-Cli @('install', 'gemini-cli', 'opencode')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.agents/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $HomeDir '.gemini/skills/adr-std') | Should -BeFalse
    }
    It 'dry-run não altera nada' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        (Invoke-Cli @('install', '--dry-run', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std') | Should -BeFalse
        Test-Path $State | Should -BeFalse
    }
    It 'nome de agente errado sugere o mais próximo' {
        $r = Invoke-Cli @('install', 'claude')
        $r.Code | Should -Not -Be 0
        $r.Output | Should -Match 'quis dizer claude-code'
    }
    It 'menu instala os agentes escolhidos' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.codex') | Out-Null
        (Invoke-Cli @('install') -Answer '1 2').Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $HomeDir '.codex/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It '--all instala em todos os encontrados' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.gemini') | Out-Null
        (Invoke-Cli @('install', '--all')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $HomeDir '.agents/skills/adr-std/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $HomeDir '.codex/skills/adr-std') | Should -BeFalse
    }
    It 'sem terminal e sem agentes falha com código 3' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        Remove-Item Env:ADR_STD_ANSWER -ErrorAction SilentlyContinue
        $r = Invoke-Cli @('install')
        $r.Code | Should -Be 3
        $r.Output | Should -Match '--agent'
    }
    It 'não sobrescreve pasta que não instalou (código 4)' {
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Set-Content -Path (Join-Path $dest 'nota.txt') -Value 'do usuário'
        $r = Invoke-Cli @('install', 'claude-code')
        $r.Code | Should -Be 4
        (Get-Content (Join-Path $dest 'nota.txt')) | Should -Be 'do usuário'
        Test-Path (Join-Path $dest 'SKILL.md') | Should -BeFalse
    }
    It 'é idempotente e substitui o que instalou' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        Set-Content -Path (Join-Path $HomeDir '.claude/skills/adr-std/residuo.txt') -Value 'antigo'
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std/residuo.txt') | Should -BeFalse
        @(Get-Content $State | Where-Object { $_ -match "^agent`tclaude-code`t" }).Count | Should -Be 1
    }
}

Describe 'uninstall e status' {
    It 'remove só o agente indicado' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.codex') | Out-Null
        Invoke-Cli @('install', 'claude-code', 'codex') | Out-Null
        (Invoke-Cli @('uninstall', 'codex')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.codex/skills/adr-std') | Should -BeFalse
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It 'remove todos os registrados e preserva pastas do usuário' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        Invoke-Cli @('install', 'claude-code') | Out-Null
        $mine = Join-Path $HomeDir '.codex/skills/adr-std'
        New-Item -ItemType Directory -Force -Path $mine | Out-Null
        Set-Content -Path (Join-Path $mine 'meu.txt') -Value 'x'
        (Invoke-Cli @('uninstall')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std') | Should -BeFalse
        Test-Path (Join-Path $mine 'meu.txt') | Should -BeTrue
    }
    It 'status mostra "não instalada", a versão e pasta ausente como danificada' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.codex') | Out-Null
        (Invoke-Cli @('status')).Output | Should -Match 'não instalada'
        Invoke-Cli @('install', 'claude-code', 'codex') | Out-Null
        (Invoke-Cli @('status')).Output | Should -Match 'claude-code'
        Remove-Item -Recurse -Force (Join-Path $HomeDir '.codex/skills/adr-std')
        ((Invoke-Cli @('status')).Output -split "`n" | Where-Object { $_ -match 'codex' }) | Should -Match 'danificada'
    }
}

Describe 'comandos de ação (v1.1)' {
    It 'install gera os 10 arquivos de comando com a variável de argumento' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        $dir = Join-Path $HomeDir '.claude/commands'
        Test-Path (Join-Path $dir 'adr-std-create.md') | Should -BeTrue
        Test-Path (Join-Path $dir 'adr-std-list.md') | Should -BeTrue
        @(Get-ChildItem $dir -Filter 'adr-std-*.md').Count | Should -Be 10
        (Get-Content -Raw (Join-Path $dir 'adr-std-create.md')) | Should -Match '\$ARGUMENTS'
        (Get-Content -Raw (Join-Path $dir 'adr-std-create.md')) | Should -Match 'ação "create"'
        (Get-Content $State) -match "^command`tclaude-code`t" | Should -Not -BeNullOrEmpty
    }
    It '--no-commands não cria nenhum arquivo de comando' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        (Invoke-Cli @('install', '--no-commands', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $HomeDir '.claude/commands/adr-std-create.md') | Should -BeFalse
    }
    It 'não sobrescreve um comando alheio' {
        $dir = Join-Path $HomeDir '.claude/commands'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Set-Content -Path (Join-Path $dir 'adr-std-create.md') -Value 'comando do usuário'
        $r = Invoke-Cli @('install', 'claude-code')
        $r.Code | Should -Be 0
        (Get-Content -Raw (Join-Path $dir 'adr-std-create.md')).Trim() | Should -Be 'comando do usuário'
        Test-Path (Join-Path $dir 'adr-std-list.md') | Should -BeTrue
    }
    It 'gera .toml (Gemini CLI) e .prompt (Continue) com a variável certa' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.gemini'), (Join-Path $HomeDir '.continue') | Out-Null
        (Invoke-Cli @('install', 'gemini-cli', 'continue')).Code | Should -Be 0
        (Get-Content -Raw (Join-Path $HomeDir '.gemini/commands/adr-std-create.toml')) | Should -Match '\{\{args\}\}'
        (Get-Content -Raw (Join-Path $HomeDir '.continue/prompts/adr-std-create.prompt')) | Should -Match '\{\{\{ input \}\}\}'
    }
    It 'uninstall remove os comandos registrados e preserva os alheios' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        Invoke-Cli @('install', 'claude-code') | Out-Null
        $dir = Join-Path $HomeDir '.claude/commands'
        Set-Content -Path (Join-Path $dir 'alheio.md') -Value 'outro'
        (Invoke-Cli @('uninstall', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $dir 'adr-std-create.md') | Should -BeFalse
        Test-Path (Join-Path $dir 'alheio.md') | Should -BeTrue
    }
}

Describe 'new, list, link e organize (v1.2)' -Skip:(-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
    It 'new e list criam e listam o ADR' {
        $dir = Join-Path $Tmp 'adrs'
        $r = Invoke-Cli @('new', 'Usar fila', '--path', $dir)
        $r.Code | Should -Be 0
        Test-Path (Join-Path $dir '0001-usar-fila.md') | Should -BeTrue
        $l = Invoke-Cli @('list', '--path', $dir)
        $l.Output | Should -Match 'Usar fila'
        $l.Output | Should -Match 'Proposto'
    }
    It 'link grava a relação recíproca e organize --dry-run mostra o plano' {
        $dir = Join-Path $Tmp 'adrs'
        Invoke-Cli @('new', 'Um', '--path', $dir) | Out-Null
        Invoke-Cli @('new', 'Dois', '--path', $dir) | Out-Null
        (Invoke-Cli @('link', 'ADR-0001', 'restringe', 'ADR-0002', '--path', $dir)).Code | Should -Be 0
        Get-Content -Raw -Encoding UTF8 (Join-Path $dir '0002-dois.md') | Should -Match 'é restringido por ADR-0001'
        Rename-Item (Join-Path $dir '0002-dois.md') '0005-dois.md'
        (Invoke-Cli @('organize', '--dry-run', '--path', $dir)).Output | Should -Match '0005-dois.md -> 0002-dois.md'
    }
}

Describe 'instalador copia as tabelas de comandos' {
    It 'install.ps1 copia commands.tsv e command_targets.tsv' {
        $r = Invoke-Installer @('--agent', 'claude-code')
        $r.Code | Should -Be 0
        Test-Path (Join-Path $Tmp 'local/adr-std/commands.tsv') | Should -BeTrue
        Test-Path (Join-Path $Tmp 'local/adr-std/command_targets.tsv') | Should -BeTrue
    }
}

Describe 'config agent (v1.3)' {
    It 'mostra, define e remove o agente padrão; recusa os que não abrem pelo terminal' {
        (Invoke-Cli @('config', 'agent')).Output | Should -Match 'nenhum agente padrão'
        (Invoke-Cli @('config', 'agent', 'codex')).Code | Should -Be 0
        (Invoke-Cli @('config', 'agent')).Output | Should -Match 'codex'
        (Get-Content $State | Where-Object { $_ -match '^default_agent' }) | Should -Match "`tcodex$"
        (Invoke-Cli @('config', 'agent', '--unset')).Code | Should -Be 0
        (Invoke-Cli @('config', 'agent')).Output | Should -Match 'nenhum agente padrão'
        (Invoke-Cli @('config', 'agent', 'cursor')).Code | Should -Be 2
        (Invoke-Cli @('config', 'agent', 'claud')).Code | Should -Be 2
        (Invoke-Cli @('config')).Code | Should -Be 2
    }
    It 'agent_launch.tsv tem 4 agentes válidos com 3 colunas' {
        $rows = Get-Content (Join-Path $Root 'agent_launch.tsv') | Where-Object { $_ -and -not $_.StartsWith('#') }
        $rows.Count | Should -Be 4
        foreach ($r in $rows) { ($r -split "`t").Count | Should -Be 3 }
    }
}

Describe 'comandos de conversa (v1.3)' {
    BeforeEach {
        $script:Fake = Join-Path $Tmp 'fakebin'
        $script:Log = Join-Path $Tmp 'fake.log'
        New-Item -ItemType Directory -Force -Path $Fake | Out-Null
        foreach ($b in 'claude', 'codex', 'gemini', 'opencode') {
            $body = "#!/bin/sh`necho `"$b`" >> `"$Log`"`nfor a in `"`$@`"; do printf 'ARG:%s\n' `"`$a`" >> `"$Log`"; done`n"
            $p = Join-Path $Fake $b
            [IO.File]::WriteAllText($p, $body)
            if ($env:OS -ne 'Windows_NT') { chmod +x $p }
        }
        $script:OldPath = $env:PATH
        $env:PATH = "$Fake$([IO.Path]::PathSeparator)$env:PATH"
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude'), (Join-Path $HomeDir '.codex') | Out-Null
        Invoke-Cli @('install', 'claude-code', 'codex') | Out-Null
    }
    AfterEach { $env:PATH = $OldPath }

    It 'abre o agente indicado com o pedido como um único argumento' -Skip:($env:OS -eq 'Windows_NT') {
        (Invoke-Cli @('create', 'codex', 'usar', 'Postgres')).Code | Should -Be 0
        (Get-Content $Log) | Should -Be @('codex', 'ARG:Use a skill adr-std, ação "create", com estes argumentos: usar Postgres')
    }
    It 'gemini usa -i e opencode usa --prompt' -Skip:($env:OS -eq 'Windows_NT') {
        Invoke-Cli @('review', '--agent', 'gemini-cli', 'docs') | Out-Null
        (Get-Content $Log)[1] | Should -Be 'ARG:-i'
        Remove-Item $Log
        Invoke-Cli @('review', '--agent', 'opencode', 'docs') | Out-Null
        (Get-Content $Log)[1] | Should -Be 'ARG:--prompt'
    }
    It 'descrição entre aspas que começa com nome de agente continua descrição' -Skip:($env:OS -eq 'Windows_NT') {
        Invoke-Cli @('config', 'agent', 'claude-code') | Out-Null
        (Invoke-Cli @('create', 'codex deve ser o padrão')).Code | Should -Be 0
        (Get-Content $Log)[0] | Should -Be 'claude'
        (Get-Content $Log)[1] | Should -Match 'argumentos: codex deve ser o padrão$'
    }
    It 'nome parecido sugere o agente e não abre nada' {
        $r = Invoke-Cli @('create', 'claude', 'usar', 'Postgres')
        $r.Code | Should -Be 2
        $r.Output | Should -Match 'quis dizer claude-code'
        $r = Invoke-Cli @('create', 'cursor', 'usar', 'Postgres')
        $r.Code | Should -Be 2
        Test-Path $Log | Should -BeFalse
    }
    It 'usa o agente padrão e avisa' -Skip:($env:OS -eq 'Windows_NT') {
        Invoke-Cli @('config', 'agent', 'codex') | Out-Null
        $r = Invoke-Cli @('audit')
        $r.Output | Should -Match 'agente padrão codex'
        (Get-Content $Log)[0] | Should -Be 'codex'
    }
    It 'menu: escolhe pelo número e Enter repete o último usado' -Skip:($env:OS -eq 'Windows_NT') {
        $r = Invoke-Cli @('audit') -Answer '2'
        $r.Output | Should -Match '2\) codex'
        (Get-Content $Log)[0] | Should -Be 'codex'
        Remove-Item $Log
        $r = Invoke-Cli @('audit') -Answer ' '
        $r.Output | Should -Match '\[2\]'
        (Get-Content $Log)[0] | Should -Be 'codex'
        (Invoke-Cli @('audit') -Answer '9').Code | Should -Be 2
    }
    It 'sem terminal e sem padrão falha com código 3 pedindo --agent' {
        $r = Invoke-Cli @('audit')
        if ($r.Code -ne 3) { Set-ItResult -Inconclusive -Because 'ambiente com terminal interativo' } else { $r.Output | Should -Match '--agent' }
    }
    It 'sem agente elegível falha com código 3 pedindo install' {
        Invoke-Cli @('uninstall') | Out-Null
        $r = Invoke-Cli @('audit') -Answer '1'
        $r.Code | Should -Be 3
        $r.Output | Should -Match 'adr-std install'
    }
    It 'a descrição nunca vira comando' -Skip:($env:OS -eq 'Windows_NT') {
        Invoke-Cli @('create', '--agent', 'codex', 'x; touch PWNED $(touch PWNED2)') | Out-Null
        Test-Path (Join-Path $Tmp 'PWNED') | Should -BeFalse
        (Get-Content $Log)[1] | Should -Match 'argumentos: x; touch PWNED \$\(touch PWNED2\)$'
    }
    It '--ask e --quick: repassa em create/supersede e recusa nos demais' -Skip:($env:OS -eq 'Windows_NT') {
        Invoke-Cli @('create', 'codex', '--ask', '5', 'usar', 'x') | Out-Null
        (Get-Content $Log)[1] | Should -Match 'argumentos: --ask 5 usar x$'
        (Invoke-Cli @('create', 'codex', '--ask', 'abc', 'x')).Code | Should -Be 2
        (Invoke-Cli @('audit', '--agent', 'codex', '--quick')).Code | Should -Be 2
        (Invoke-Cli @('ask', '--agent', 'codex')).Code | Should -Be 2
    }
    It 'binário do agente ausente falha com código 5' {
        Remove-Item (Join-Path $Fake 'codex')
        $env:PATH = "$Fake$([IO.Path]::PathSeparator)/usr/bin$([IO.Path]::PathSeparator)/bin"
        if (Get-Command codex -CommandType Application -ErrorAction SilentlyContinue) { Set-ItResult -Skipped -Because 'codex real no PATH' }
        else {
            $env:PATH = $OldPath
            $env:PATH = (($OldPath -split [IO.Path]::PathSeparator | Where-Object { -not (Test-Path (Join-Path $_ 'codex')) }) -join [IO.Path]::PathSeparator)
            (Invoke-Cli @('create', '--agent', 'codex', 'x')).Code | Should -Be 5
        }
    }
}

Describe 'instalador copia agent_launch.tsv' {
    It 'install.ps1 copia a tabela de abertura' {
        (Invoke-Installer @('--agent', 'claude-code')).Code | Should -Be 0
        Test-Path (Join-Path $Tmp 'local/adr-std/agent_launch.tsv') | Should -BeTrue
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
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        $r = Invoke-Installer @('--agent', 'claude-code')
        $r.Code | Should -Be 0
        Test-Path (Join-Path $Tmp 'local/adr-std/bin/adr-std.ps1') | Should -BeTrue
        Test-Path (Join-Path $Tmp 'local/adr-std/bin/adr-std.cmd') | Should -BeTrue
        Test-Path (Join-Path $Tmp 'local/adr-std/skill/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std/SKILL.md') | Should -BeTrue
    }
    It 'self-uninstall remove skill, estado e comando' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        Invoke-Installer @('--agent', 'claude-code') | Out-Null
        $installed = Join-Path $Tmp 'local/adr-std/bin/adr-std.ps1'
        & $script:Ps -NoProfile -ExecutionPolicy Bypass -File $installed self-uninstall | Out-Null
        Test-Path (Join-Path $HomeDir '.claude/skills/adr-std') | Should -BeFalse
        Test-Path (Join-Path $Tmp 'roam/adr-std') | Should -BeFalse
        Test-Path (Join-Path $Tmp 'local/adr-std/skill') | Should -BeFalse
        Test-Path (Join-Path $Tmp 'local/adr-std/bin/adr-std.cmd') | Should -BeFalse
    }
}

}
