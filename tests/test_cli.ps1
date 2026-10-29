# Testes do comando adr-std e do instalador para Windows (Pester 5).
# Uso: Invoke-Pester -Path tests/test_cli.ps1 -CI
# Cada teste roda num perfil temporário (ADR_STD_HOME, ADR_STD_LOCALAPPDATA, ADR_STD_APPDATA); o perfil real nunca é usado.
# Espelha tests/test_cli.sh. Executado com PowerShell 7 no Linux (parcial) e no job windows-latest do CI (nativo).

Describe 'adr-std' {

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    $script:Cli = Join-Path $Root 'bin/adr-std.ps1'
    $script:Installer = Join-Path $Root 'install.ps1'
    $script:Ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

    function Invoke-Cli {
        param([string[]]$CliArgs, [object]$Answer = $null)
        # [string] com $null vira ''; no Windows variável de ambiente vazia não existe, então resposta vazia usa ' '.
        if ($null -ne $Answer) { $env:ADR_STD_ANSWER = $Answer } else { Remove-Item Env:ADR_STD_ANSWER -ErrorAction SilentlyContinue }
        # stdin redirecionado: sem terminal de verdade, o prompt nunca trava um console interativo.
        $out = $null | & $script:Ps -NoProfile -ExecutionPolicy Bypass -File $script:Cli @CliArgs 2>&1 | Out-String
        [pscustomobject]@{ Output = $out; Code = $LASTEXITCODE }
    }

    # Link para pasta: junção no Windows, link simbólico nos demais sistemas (a cadeia funciona nos dois).
    function New-TestLink {
        param([string]$Path, [string]$Target)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        $type = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $type -Path $Path -Target $Target | Out-Null
    }

    function New-TestSkillDir {
        param([string]$Dir, [string]$Name)
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Set-Content -Path (Join-Path $Dir 'SKILL.md') -Value "---`nname: $Name`n---`ncorpo"
    }

    function Get-TreeSnapshot {
        $items = Get-ChildItem -LiteralPath $script:HomeDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            # Pasta: sem data. No NTFS a data da pasta é atualizada de forma preguiçosa e muda só por leitura.
            "{0}|{1}|{2}" -f $_.FullName, $(if ($_.PSIsContainer) { 'd' } else { $_.Length }), $(if ($_.PSIsContainer) { 0 } else { $_.LastWriteTimeUtc.Ticks })
        }
        $st = if (Test-Path $script:State) { Get-Content -Raw $script:State } else { '' }
        (($items | Sort-Object) -join "`n") + "`n--`n" + $st
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
    Remove-Item Env:ADR_STD_HOME, Env:ADR_STD_LOCALAPPDATA, Env:ADR_STD_APPDATA, Env:ADR_STD_NO_PATH, Env:ADR_STD_ANSWER, Env:ADR_STD_TODAY -ErrorAction SilentlyContinue
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
        foreach ($c in 'install', 'update', 'uninstall', 'self-uninstall', 'status', 'agents', 'check', 'new', 'list', 'link', 'organize', 'migrate', 'create', 'supersede', 'review', 'audit', 'ask', 'config', 'version') { $r.Output | Should -Match $c }
        (Invoke-Cli @('comando-inexistente')).Code | Should -Be 2
    }
    It 'help descreve migrate com --apply e --exclude' {
        $r = Invoke-Cli @('help')
        $lines = $r.Output -split "`n"
        $i = [array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match '^\s+migrate\b' })
        $line = ($lines[$i], $lines[$i + 1]) -join ' '
        $line | Should -Match '--apply'
        $line | Should -Match '--exclude'
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

Describe 'adoção automática de pastas existentes' {
    It 'install registra o modo por agente e status o mostra' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        (Get-Content $State) -match "^agent`tclaude-code`t.*`tcopy$" | Should -Not -BeNullOrEmpty
        $line = (Invoke-Cli @('status')).Output -split "`n" | Where-Object { $_ -match 'claude-code' }
        $line | Should -Match 'íntegra, copy'
    }
    It 'estado antigo de 3 colunas usa o modo global no status' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        Invoke-Cli @('install', 'claude-code') | Out-Null
        $lines = Get-Content $State | ForEach-Object { if ($_ -match "^agent`t") { ($_ -split "`t")[0..2] -join "`t" } else { $_ } }
        Set-Content -Path $State -Value $lines
        ((Invoke-Cli @('status')).Output -split "`n" | Where-Object { $_ -match 'claude-code' }) | Should -Match 'íntegra, copy'
    }
    It 'link para o repositório (direto e encadeado) é registrado sem alterar nem criar backup' {
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        $mid = Join-Path $Tmp 'mid'
        New-TestLink $mid (Join-Path $Root 'skill')
        New-TestLink $dest $mid
        $r = Invoke-Cli @('install', 'claude-code')
        $r.Code | Should -Be 0
        (Get-Item -LiteralPath $dest -Force).Attributes -band [IO.FileAttributes]::ReparsePoint | Should -Not -Be 0
        (Get-Content -Raw (Join-Path $dest 'SKILL.md')) | Should -Be (Get-Content -Raw (Join-Path $Root 'skill/SKILL.md'))
        @(Get-ChildItem -LiteralPath (Join-Path $HomeDir '.claude/skills') -Force | Where-Object { $_.Name -like '*.bak-*' }).Count | Should -Be 0
        (Get-Content $State) -match "^agent`tclaude-code`t.*`tlink$" | Should -Not -BeNullOrEmpty
    }
    It 'outra skill no destino é pulada (código 4) e os demais agentes seguem' {
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestSkillDir $dest 'outra-skill'
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.codex') | Out-Null
        $r = Invoke-Cli @('install', 'claude-code', 'codex')
        $r.Code | Should -Be 4
        $r.Output | Should -Match 'outra-skill'
        (Get-Content -Raw (Join-Path $dest 'SKILL.md')) | Should -Match 'outra-skill'
        Test-Path (Join-Path $HomeDir '.codex/skills/adr-std/SKILL.md') | Should -BeTrue
        (Get-Content $State) -match "^agent`tclaude-code`t" | Should -BeNullOrEmpty
    }
    It 'adr-std alheio: resposta s adota com backup' {
        $env:ADR_STD_TODAY = '2026-10-27'
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestSkillDir $dest 'adr-std'
        Set-Content -Path (Join-Path $dest 'extra.txt') -Value 'original'
        $r = Invoke-Cli @('install', 'claude-code') -Answer 's'
        $r.Code | Should -Be 0
        (Get-Content (Join-Path $HomeDir '.claude/skills/adr-std.bak-2026-10-27/extra.txt')) | Should -Be 'original'
        Test-Path (Join-Path $dest '.installed-by-adr-std') | Should -BeTrue
        (Get-Content $State) -match "^agent`tclaude-code`t" | Should -Not -BeNullOrEmpty
    }
    It 'adr-std alheio: resposta n, vazia ou lixo recusa sem backup e sem rastro' {
        $env:ADR_STD_TODAY = '2026-10-27'
        foreach ($answer in 'n', ' ', 'xyz') {
            $dest = Join-Path $HomeDir '.claude/skills/adr-std'
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $dest, (Join-Path $HomeDir '.claude/skills/adr-std.bak-2026-10-27'), (Join-Path $Tmp 'roam/adr-std')
            New-TestSkillDir $dest 'adr-std'
            Set-Content -Path (Join-Path $dest 'extra.txt') -Value 'original'
            $r = Invoke-Cli @('install', 'claude-code') -Answer $answer
            $r.Code | Should -Be 4
            $r.Output | Should -Match 'recusado'
            (Get-Content (Join-Path $dest 'extra.txt')) | Should -Be 'original'
            Test-Path (Join-Path $HomeDir '.claude/skills/adr-std.bak-2026-10-27') | Should -BeFalse
            # Os comandos /adr-std-* ainda são instalados (RF-09); só não pode haver linha de agente.
            if (Test-Path $State) { @(Get-Content $State | Where-Object { $_ -match '^agent' }).Count | Should -Be 0 }
        }
    }
    It 'sem terminal e sem --adopt pula com a dica de --adopt' {
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestSkillDir $dest 'adr-std'
        Remove-Item Env:ADR_STD_ANSWER -ErrorAction SilentlyContinue
        $r = Invoke-Cli @('install', 'claude-code')
        $r.Code | Should -Be 4
        $r.Output | Should -Match 'sem-terminal'
        $r.Output | Should -Match '--adopt'
        Test-Path (Join-Path $dest '.installed-by-adr-std') | Should -BeFalse
    }
    It '--adopt adota com backup sem perguntar, mas nunca vale para outra skill' {
        $env:ADR_STD_TODAY = '2026-10-27'
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestSkillDir $dest 'adr-std'
        Set-Content -Path (Join-Path $dest 'extra.txt') -Value 'original'
        New-TestSkillDir (Join-Path $HomeDir '.codex/skills/adr-std') 'outra-skill'
        $r = Invoke-Cli @('install', 'claude-code', 'codex', '--adopt')
        $r.Code | Should -Be 4
        $r.Output | Should -Not -Match 'Adotar\?'
        (Get-Content (Join-Path $HomeDir '.claude/skills/adr-std.bak-2026-10-27/extra.txt')) | Should -Be 'original'
        Test-Path (Join-Path $dest '.installed-by-adr-std') | Should -BeTrue
        (Get-Content -Raw (Join-Path $HomeDir '.codex/skills/adr-std/SKILL.md')) | Should -Match 'outra-skill'
        @(Get-ChildItem -LiteralPath (Join-Path $HomeDir '.codex/skills') -Force | Where-Object { $_.Name -like '*.bak-*' }).Count | Should -Be 0
    }
    It 'link atrás de pasta-pai que também é link continua repo-link (caminho físico, SEG-01)' {
        $alias = Join-Path $Tmp 'alias'
        New-TestLink $alias $Root
        New-TestLink (Join-Path $HomeDir '.claude/skills/adr-std') (Join-Path $alias 'skill')
        $r = Invoke-Cli @('install', 'claude-code', '--dry-run')
        $r.Code | Should -Be 0
        ($r.Output -split "`n" | Where-Object { $_ -match 'claude' -and $_ -match '->' }) | Should -Match 'repo-link -> registraria sem alterar'
    }
    It 'ciclo de links no destino é foreign-other e é pulado' {
        $a = Join-Path $Tmp 'ca'; $b = Join-Path $Tmp 'cb'
        try {
            New-TestLink $a (Join-Path $Root 'skill')
            New-TestLink $b $a
            (Get-Item -LiteralPath $a -Force).Delete()
            New-TestLink $a $b
            New-TestLink (Join-Path $HomeDir '.claude/skills/adr-std') $a
        } catch { Set-ItResult -Skipped -Because "não foi possível criar o ciclo de links: $($_.Exception.Message)"; return }
        $r = Invoke-Cli @('install', 'claude-code', '--dry-run')
        $r.Code | Should -Be 0
        ($r.Output -split "`n" | Where-Object { $_ -match 'claude' -and $_ -match '->' }) | Should -Match 'foreign-other -> pularia'
    }
    It 'cadeia de 10 links resolve e de 11 links falha (SEG-02)' {
        New-TestLink (Join-Path $Tmp 'n1') (Join-Path $Root 'skill')
        foreach ($i in 2..10) { New-TestLink (Join-Path $Tmp "n$i") (Join-Path $Tmp "n$($i - 1)") }
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestLink $dest (Join-Path $Tmp 'n9')
        $line = { ((Invoke-Cli @('install', 'claude-code', '--dry-run')).Output -split "`n" | Where-Object { $_ -match 'claude' -and $_ -match '->' }) }
        (& $line) | Should -Match 'repo-link'
        (Get-Item -LiteralPath $dest -Force).Delete()
        New-TestLink $dest (Join-Path $Tmp 'n10')
        (& $line) | Should -Match 'foreign-other'
    }
    It 'backup usa o sufixo -2 e -3 quando o nome do dia já existe' {
        $env:ADR_STD_TODAY = '2026-10-27'
        $skills = Join-Path $HomeDir '.claude/skills'
        New-Item -ItemType Directory -Force -Path (Join-Path $skills 'adr-std.bak-2026-10-27') | Out-Null
        $dest = Join-Path $skills 'adr-std'
        New-TestSkillDir $dest 'adr-std'
        Set-Content -Path (Join-Path $dest 'extra.txt') -Value 'primeiro'
        (Invoke-Cli @('install', 'claude-code', '--adopt')).Code | Should -Be 0
        (Get-Content (Join-Path $skills 'adr-std.bak-2026-10-27-2/extra.txt')) | Should -Be 'primeiro'
        Remove-Item -Recurse -Force $dest
        New-TestSkillDir $dest 'adr-std'
        Set-Content -Path (Join-Path $dest 'extra.txt') -Value 'segundo'
        (Invoke-Cli @('install', 'claude-code', '--adopt')).Code | Should -Be 0
        (Get-Content (Join-Path $skills 'adr-std.bak-2026-10-27-3/extra.txt')) | Should -Be 'segundo'
    }
    It 'backup de link para outro clone move o link e não toca no alvo' {
        $env:ADR_STD_TODAY = '2026-10-27'
        $other = Join-Path $Tmp 'outro-clone/skill'
        New-TestSkillDir $other 'adr-std'
        Set-Content -Path (Join-Path $other 'extra.txt') -Value 'alvo'
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestLink $dest $other
        (Invoke-Cli @('install', 'claude-code', '--adopt')).Code | Should -Be 0
        $bak = Join-Path $HomeDir '.claude/skills/adr-std.bak-2026-10-27'
        (Get-Item -LiteralPath $bak -Force).LinkType | Should -BeIn 'Junction', 'SymbolicLink'
        (Get-Content (Join-Path $other 'extra.txt')) | Should -Be 'alvo'
        Test-Path (Join-Path $dest '.installed-by-adr-std') | Should -BeTrue
        (Get-Item -LiteralPath $dest -Force).LinkType | Should -BeNullOrEmpty
    }
    It 'pasta compartilhada por dois agentes aparece uma vez só (RF-12)' {
        $r = Invoke-Cli @('install', 'gemini-cli', 'opencode', '--dry-run')
        $r.Code | Should -Be 0
        @($r.Output -split "`n" | Where-Object { $_ -match '\.agents' -and $_ -match '->' }).Count | Should -Be 1
    }
    It 'segunda instalação de link adotado mantém o modo link sem --link (D-16)' {
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestLink $dest (Join-Path $Root 'skill')
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        (Invoke-Cli @('install', 'claude-code')).Code | Should -Be 0
        (Get-Item -LiteralPath $dest -Force).LinkType | Should -BeIn 'Junction', 'SymbolicLink'
        (Get-Content $State) -match "^agent`tclaude-code`t.*`tlink$" | Should -Not -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath (Join-Path $HomeDir '.claude/skills') -Force | Where-Object { $_.Name -like '*.bak-*' }).Count | Should -Be 0
    }
    It 'dry-run mostra classe e ação por destino sem alterar arquivos nem estado' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        Invoke-Cli @('install', 'claude-code') | Out-Null
        New-TestLink (Join-Path $HomeDir '.codex/skills/adr-std') (Join-Path $Root 'skill')
        New-TestSkillDir (Join-Path $HomeDir '.cursor/skills/adr-std') 'adr-std'
        New-TestSkillDir (Join-Path $HomeDir '.roo/skills/adr-std') 'outra-skill'
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.codeium/windsurf') | Out-Null
        $before = Get-TreeSnapshot
        $r = Invoke-Cli @('install', 'claude-code', 'codex', 'cursor', 'roo', 'windsurf', '--dry-run') -Answer 'x'
        $after = Get-TreeSnapshot
        $r.Code | Should -Be 0
        $after | Should -Be $before
        $lines = $r.Output -split "`n"
        # só a linha de classe: as linhas de comando também têm 'claude' no caminho
        ($lines | Where-Object { $_ -match 'claude' -and $_ -match '->' }) | Should -Match 'ours -> atualizaria'
        ($lines | Where-Object { $_ -match 'codex' }) | Should -Match 'repo-link -> registraria sem alterar'
        ($lines | Where-Object { $_ -match 'cursor' }) | Should -Match 'foreign-adr-std -> perguntaria'
        ($lines | Where-Object { $_ -match '\.roo' }) | Should -Match 'foreign-other -> pularia'
        ($lines | Where-Object { $_ -match 'windsurf' }) | Should -Match 'absent -> instalaria'
        $r.Output | Should -Not -Match 'Adotar\?'
    }
    It 'dry-run com --adopt mostra adotaria' {
        New-TestSkillDir (Join-Path $HomeDir '.cursor/skills/adr-std') 'adr-std'
        $r = Invoke-Cli @('install', 'cursor', '--dry-run', '--adopt')
        $r.Output | Should -Match 'foreign-adr-std -> adotaria'
    }
    It 'uninstall de link adotado remove o link, mantém o alvo e o backup' {
        $dest = Join-Path $HomeDir '.claude/skills/adr-std'
        New-TestLink $dest (Join-Path $Root 'skill')
        $bak = Join-Path $HomeDir '.claude/skills/adr-std.bak-2026-10-27'
        New-Item -ItemType Directory -Force -Path $bak | Out-Null
        Set-Content -Path (Join-Path $bak 'x.txt') -Value 'bak'
        Invoke-Cli @('install', 'claude-code') | Out-Null
        (Invoke-Cli @('uninstall', 'claude-code')).Code | Should -Be 0
        Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Test-Path (Join-Path $Root 'skill/SKILL.md') | Should -BeTrue
        (Get-Content (Join-Path $bak 'x.txt')) | Should -Be 'bak'
    }
    It 'help cita --adopt e o código 4' {
        $r = Invoke-Cli @('help')
        $r.Output | Should -Match '--adopt'
        $r.Output | Should -Match 'código 4'
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
        $r = Invoke-Cli @('new', 'Usar fila', '--path', $dir, '--create')
        $r.Code | Should -Be 0
        Test-Path (Join-Path $dir '1-usar-fila.md') | Should -BeTrue
        $l = Invoke-Cli @('list', '--path', $dir)
        $l.Output | Should -Match 'Usar fila'
        $l.Output | Should -Match 'Proposto'
    }
    It 'new de subpasta de repositório grava na pasta de ADRs da raiz' {
        $repo = Join-Path $Tmp 'repo-raiz'
        $sub = Join-Path $repo 'docs/architecture/ADR'
        New-Item -ItemType Directory -Path $sub -Force | Out-Null
        git init -q $repo
        Push-Location $sub
        try { $r = Invoke-Cli @('new', 'Da subpasta') } finally { Pop-Location }
        $r.Code | Should -Be 0
        Test-Path (Join-Path $sub '1-da-subpasta.md') | Should -BeTrue
        Test-Path (Join-Path $sub 'docs') | Should -BeFalse
    }
    It 'config path gravado pelo wrapper em APPDATA é lido por new e list (ADR-1, só Windows)' -Skip:($env:OS -ne 'Windows_NT') {
        $repo = Join-Path $Tmp 'repo-cfg'
        New-Item -ItemType Directory -Path (Join-Path $repo 'custom-adrs') -Force | Out-Null
        git init -q $repo
        (Invoke-Cli @('config', 'path', 'custom-adrs')).Code | Should -Be 0
        Push-Location $repo
        try { $n = Invoke-Cli @('new', 'Da config'); $l = Invoke-Cli @('list') } finally { Pop-Location }
        $n.Code | Should -Be 0
        Test-Path (Join-Path $repo 'custom-adrs/1-da-config.md') | Should -BeTrue
        $l.Output | Should -Match 'Da config'
    }
    It 'link grava a relação recíproca e organize --dry-run mostra o plano' {
        $dir = Join-Path $Tmp 'adrs'
        Invoke-Cli @('new', 'Um', '--path', $dir, '--create') | Out-Null
        Invoke-Cli @('new', 'Dois', '--path', $dir) | Out-Null
        (Invoke-Cli @('link', 'ADR-1', 'restringe', 'ADR-2', '--path', $dir)).Code | Should -Be 0
        Get-Content -Raw -Encoding UTF8 (Join-Path $dir '2-dois.md') | Should -Match 'é restringido por ADR-1'
        Rename-Item (Join-Path $dir '2-dois.md') '5-dois.md'
        (Invoke-Cli @('organize', '--dry-run', '--path', $dir)).Output | Should -Match '5-dois.md -> 2-dois.md'
    }
}

Describe 'migrate (v2.0)' {
    BeforeEach {
        $script:Proj = Join-Path $Tmp 'proj'
        $script:AdrDir = Join-Path $Proj 'docs/architecture/ADR'
        New-Item -ItemType Directory -Force -Path $AdrDir | Out-Null
        Set-Content -Path (Join-Path $AdrDir '0001-a.md') -Value '# ADR-0001: A'
        Set-Content -Path (Join-Path $Proj 'README.md') -Value 'Veja [A](docs/architecture/ADR/0001-a.md).'
    }
    It 'sem --apply mostra o plano e não altera arquivo' -Skip:(-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
        $r = Invoke-Cli @('migrate', '--root', $Proj)
        $r.Code | Should -Be 0
        $r.Output | Should -Match '0001-a.md'
        $r.Output | Should -Match '1-a.md'
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
        Test-Path (Join-Path $AdrDir '1-a.md') | Should -BeFalse
        Get-Content -Raw (Join-Path $Proj 'README.md') | Should -Match '0001-a.md'
    }
    It '--apply renomeia o ADR e corrige o link do README' -Skip:(-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
        $r = Invoke-Cli @('migrate', '--apply', '--root', $Proj)
        $r.Code | Should -Be 0
        Test-Path (Join-Path $AdrDir '1-a.md') | Should -BeTrue
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeFalse
        Get-Content -Raw (Join-Path $Proj 'README.md') | Should -Match 'docs/architecture/ADR/1-a.md'
    }
    It 'sem Python 3 sai com código 6 e indica o checklist' {
        $psPath = (Get-Command $script:Ps).Source
        $oldPath = $env:PATH
        try {
            $env:PATH = Split-Path -Parent $psPath
            $hasPython = [bool](Get-Command python3 -ErrorAction SilentlyContinue) -or [bool](Get-Command python -ErrorAction SilentlyContinue) -or [bool](Get-Command py -ErrorAction SilentlyContinue)
            if ($hasPython) { Set-ItResult -Skipped -Because 'Python 3 está na mesma pasta do PowerShell'; return }
            $out = & $psPath -NoProfile -ExecutionPolicy Bypass -File $script:Cli 'migrate' 2>&1 | Out-String
            $code = $LASTEXITCODE
        } finally { $env:PATH = $oldPath }
        $code | Should -Be 6
        $out | Should -Match 'Python'
        $out | Should -Match 'checklist'
    }
}

Describe 'update (v2.0): gancho de migração' {
    # O instalador instalado (local/adr-std/install.ps1) é trocado por um falso; o gancho roda o
    # migrate_numbering.py real da fonte. Espelha tests/test_cli.sh (update_*).
    # Calculado na fase Discovery: -Skip é avaliado antes de qualquer BeforeAll (Pester 5), então uma
    # variável definida só em BeforeAll chega nula e pula todos os casos (RF-04).
    $HasPython = [bool](Get-Command python -ErrorAction SilentlyContinue) -or [bool](Get-Command python3 -ErrorAction SilentlyContinue) -or [bool](Get-Command py -ErrorAction SilentlyContinue)
    BeforeAll {
        function Invoke-UpdateIn {
            param([string[]]$UpdateArgs = @(), [object]$Answer = $null, [string]$WorkDir)
            Push-Location $WorkDir
            try { $r = Invoke-Cli (@('update') + $UpdateArgs) $Answer } finally { Pop-Location }
            $r
        }
    }
    BeforeEach {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        Invoke-Installer @('--agent', 'claude-code') | Out-Null
        $script:Stub = Join-Path $Tmp 'local/adr-std/install.ps1'
        Set-Content -Path $Stub -Value 'exit 0'
        $script:Proj = Join-Path $Tmp 'proj'
        $script:AdrDir = Join-Path $Proj 'docs/architecture/ADR'
        New-Item -ItemType Directory -Force -Path $AdrDir | Out-Null
        Set-Content -Path (Join-Path $AdrDir '0001-a.md') -Value '# ADR-0001: A'
        Set-Content -Path (Join-Path $Proj 'README.md') -Value 'Veja [A](docs/architecture/ADR/0001-a.md).'
    }
    It 'sem terminal imprime o plano e adr-std migrate --apply sem alterar arquivo' -Skip:(-not $HasPython) {
        $r = Invoke-UpdateIn -WorkDir $Proj
        $r.Code | Should -Be 0
        $r.Output | Should -Match '0001-a.md'
        $r.Output | Should -Match '1-a.md'
        $r.Output | Should -Match 'adr-std migrate --apply'
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
        Test-Path (Join-Path $AdrDir '1-a.md') | Should -BeFalse
    }
    It 'update não substitui destino em modo link e informa o motivo' -Skip:(-not $HasPython) {
        $lines = Get-Content $State | ForEach-Object { if ($_ -match "^agent`tclaude-code`t") { (($_ -split "`t")[0..2] -join "`t") + "`tlink" } else { $_ } }
        Set-Content -Path $State -Value $lines
        Set-Content -Path $Stub -Value 'Set-Content -Path (Join-Path $env:ADR_STD_HOME "stub-ran") -Value x; exit 0'
        $r = Invoke-UpdateIn -WorkDir $Proj
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'já segue o repositório'
        Test-Path (Join-Path $HomeDir 'stub-ran') | Should -BeFalse
        $r.Output | Should -Match 'adr-std migrate --apply'
    }
    It 'update --agent de agente não registrado ignora o modo global link' {
        $lines = (Get-Content $State | Where-Object { $_ -notmatch "^mode`t" }) + "mode`tlink"
        Set-Content -Path $State -Value $lines
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.cursor') | Out-Null
        Set-Content -Path $Stub -Value 'Set-Content -Path (Join-Path $env:ADR_STD_HOME "stub-ran") -Value x; exit 0'
        $r = Invoke-UpdateIn -UpdateArgs @('--no-migrate', '--agent', 'cursor') -WorkDir $Proj
        $r.Code | Should -Be 0
        Test-Path (Join-Path $HomeDir 'stub-ran') | Should -BeTrue
        $r.Output | Should -Not -Match 'cursor: .*já segue o repositório'
    }
    It 'update com código 4 do instalador ainda migra e devolve 4' -Skip:(-not $HasPython) {
        Set-Content -Path $Stub -Value 'exit 4'
        $r = Invoke-UpdateIn -WorkDir $Proj
        $r.Code | Should -Be 4
        $r.Output | Should -Match 'adr-std migrate --apply'
    }
    It 'update com outro código de erro do instalador continua interrompendo' {
        Set-Content -Path $Stub -Value 'exit 5'
        $r = Invoke-UpdateIn -WorkDir $Proj
        $r.Code | Should -Be 5
        $r.Output | Should -Not -Match 'plano de migração'
    }
    It 'com terminal e resposta s aplica a migração' -Skip:(-not $HasPython) {
        $r = Invoke-UpdateIn -WorkDir $Proj -Answer 's'
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'Aplicar a migração\? \[s/N\]'
        Test-Path (Join-Path $AdrDir '1-a.md') | Should -BeTrue
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeFalse
        Get-Content -Raw (Join-Path $Proj 'README.md') | Should -Match 'docs/architecture/ADR/1-a.md'
    }
    It 'resposta n, vazia ou outra não aplica' -Skip:(-not $HasPython) {
        foreach ($a in 'n', ' ', 'talvez') {
            $r = Invoke-UpdateIn -WorkDir $Proj -Answer $a
            $r.Code | Should -Be 0
            $r.Output | Should -Match 'Aplicar a migração\? \[s/N\]'
            Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
            Test-Path (Join-Path $AdrDir '1-a.md') | Should -BeFalse
        }
    }
    It '--no-migrate não calcula nem mostra o plano' -Skip:(-not $HasPython) {
        $r = Invoke-UpdateIn -UpdateArgs @('--no-migrate') -WorkDir $Proj -Answer 's'
        $r.Code | Should -Be 0
        $r.Output | Should -Not -Match 'plano de migração|migração: nada a fazer|Aplicar a migração'
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
    }
    It '--dry-run não migra' -Skip:(-not $HasPython) {
        $r = Invoke-UpdateIn -UpdateArgs @('--dry-run') -WorkDir $Proj -Answer 's'
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'simulação'
        $r.Output | Should -Not -Match 'plano de migração|migração: nada a fazer'
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
    }
    It 'projeto com numbering: padded ou sem pasta de ADRs só diz nada a fazer' -Skip:(-not $HasPython) {
        Set-Content -Path (Join-Path $Proj '.adr-std') -Value 'numbering: padded'
        $r = Invoke-UpdateIn -WorkDir $Proj
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'migração: nada a fazer'
        $r.Output | Should -Not -Match 'plano de migração'
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
        $empty = Join-Path $Tmp 'empty'
        New-Item -ItemType Directory -Force -Path $empty | Out-Null
        $r = Invoke-UpdateIn -WorkDir $empty
        $r.Code | Should -Be 0
        $r.Output | Should -Match 'migração: nada a fazer'
        $r.Output | Should -Not -Match 'plano de migração'
    }
    It 'sem Python 3 avisa e o update mantém o código 0' {
        $psPath = (Get-Command $script:Ps).Source
        $oldPath = $env:PATH
        try {
            $env:PATH = Split-Path -Parent $psPath
            $hasPy = [bool](Get-Command python3 -ErrorAction SilentlyContinue) -or [bool](Get-Command python -ErrorAction SilentlyContinue) -or [bool](Get-Command py -ErrorAction SilentlyContinue)
            if ($hasPy) { Set-ItResult -Skipped -Because 'Python 3 está na mesma pasta do PowerShell'; return }
            Push-Location $Proj
            try { $out = & $psPath -NoProfile -ExecutionPolicy Bypass -File $script:Cli 'update' 2>&1 | Out-String; $code = $LASTEXITCODE } finally { Pop-Location }
        } finally { $env:PATH = $oldPath }
        $code | Should -Be 0
        $out | Should -Match 'aviso'
        $out | Should -Match 'Python'
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
    }
    It 'falha do instalador mantém o código e não dispara a migração' -Skip:(-not $HasPython) {
        Set-Content -Path $Stub -Value 'exit 5'
        $r = Invoke-UpdateIn -WorkDir $Proj -Answer 's'
        $r.Code | Should -Be 5
        $r.Output | Should -Not -Match 'plano de migração|migração: nada a fazer|Aplicar a migração'
        Test-Path (Join-Path $AdrDir '0001-a.md') | Should -BeTrue
    }
    It 'help lista update --no-migrate' {
        $r = Invoke-Cli @('help')
        $r.Output | Should -Match '--no-migrate'
        $r.Output | Should -Match 'plano de migração'
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

Describe 'config path (v1.4)' {
    It 'mostra, define e remove a pasta de ADRs na config global' {
        $config = Join-Path $Tmp 'roam/adr-std/config'
        (Invoke-Cli @('config', 'path')).Output | Should -Match 'nenhuma pasta de ADRs'
        (Invoke-Cli @('config', 'path', 'docs/decisoes')).Code | Should -Be 0
        (Invoke-Cli @('config', 'path')).Output | Should -Match 'docs/decisoes'
        (@(Get-Content $config) -match '^path\s*[:=]').Count | Should -Be 1
        # gravar de novo não duplica
        (Invoke-Cli @('config', 'path', 'docs/decisoes')).Code | Should -Be 0
        (@(Get-Content $config) -match '^path\s*[:=]').Count | Should -Be 1
        # config path (config) e config agent (state) não interferem
        (Invoke-Cli @('config', 'agent', 'codex')).Code | Should -Be 0
        (Invoke-Cli @('config', 'path', 'docs/decisoes')).Code | Should -Be 0
        (Get-Content $State | Where-Object { $_ -match '^default_agent' }) | Should -Match "`tcodex$"
        (Invoke-Cli @('config', 'path')).Output | Should -Match 'docs/decisoes'
        # remover
        (Invoke-Cli @('config', 'path', '--unset')).Code | Should -Be 0
        (Invoke-Cli @('config', 'path')).Output | Should -Match 'nenhuma pasta de ADRs'
        (Invoke-Cli @('config', 'path', '--unset')).Code | Should -Be 0
        # opção desconhecida e subcomando inválido
        (Invoke-Cli @('config', 'path', '-x')).Code | Should -Be 2
        $r = Invoke-Cli @('config', 'caminho')
        $r.Code | Should -Be 2
        $r.Output | Should -Match 'agent'
        $r.Output | Should -Match 'path'
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
        # stdin redirecionado simula a execução sem terminal, também com terminal interativo no host
        Remove-Item Env:ADR_STD_ANSWER -ErrorAction SilentlyContinue
        $out = $null | & $script:Ps -NoProfile -ExecutionPolicy Bypass -File $script:Cli 'audit' 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 3
        $out | Should -Match '--agent'
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
        (Invoke-Cli @('check', (Join-Path $Root 'tests/fixtures/1-cache-de-sessao-em-redis.md'))).Code | Should -Be 0
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

Describe 'Windows nativo: junção NTFS, .cmd e PATH' -Skip:($env:OS -ne 'Windows_NT') {
    It 'install --link cria junção NTFS para a skill da fonte' {
        New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir '.claude') | Out-Null
        (Invoke-Cli @('install', '--link', 'claude-code')).Code | Should -Be 0
        $dest = Get-Item -LiteralPath (Join-Path $HomeDir '.claude/skills/adr-std') -Force
        $dest.LinkType | Should -Be 'Junction'
        Test-Path (Join-Path $dest.FullName 'SKILL.md') | Should -BeTrue
    }
    It 'adr-std.cmd instalado executa version pelo cmd.exe' {
        Invoke-Installer @('--agent', 'claude-code') | Out-Null
        $cmd = Join-Path $Tmp 'local/adr-std/bin/adr-std.cmd'
        $out = & cmd.exe /c "`"$cmd`" version" 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match ((Get-Content -Raw (Join-Path $Root 'VERSION')).Trim())
    }
    # Altera o PATH real do usuário: só roda no CI (runner descartável) e restaura o valor original.
    It 'instalador acrescenta a pasta do comando ao PATH do usuário e o self-uninstall a remove' -Skip:(-not $env:GITHUB_ACTIONS) {
        $original = [Environment]::GetEnvironmentVariable('Path', 'User')
        $bin = Join-Path $Tmp 'local/adr-std/bin'
        try {
            Remove-Item Env:ADR_STD_NO_PATH -ErrorAction SilentlyContinue
            (Invoke-Installer @('--agent', 'claude-code') 's').Code | Should -Be 0
            @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') | Should -Contain $bin
            $env:ADR_STD_ANSWER = 's'
            & $script:Ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bin 'adr-std.ps1') self-uninstall | Out-Null
            @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') | Should -Not -Contain $bin
        } finally {
            [Environment]::SetEnvironmentVariable('Path', $original, 'User')
        }
    }
}

}
