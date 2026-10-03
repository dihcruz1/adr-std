# adr-std — instala, atualiza e gerencia a skill adr-std nos agentes de código (Windows).
# Mesma lógica de bin/adr-std (bash). Compatível com Windows PowerShell 5.1 e PowerShell 7+.
# https://github.com/dihcruz1/adr-std

$ErrorActionPreference = 'Stop'

# --- locais -------------------------------------------------------------------
# ADR_STD_HOME, ADR_STD_LOCALAPPDATA e ADR_STD_APPDATA existem só para os testes.

$UserHome  = if ($env:ADR_STD_HOME) { $env:ADR_STD_HOME } else { $env:USERPROFILE }
$LocalApp  = if ($env:ADR_STD_LOCALAPPDATA) { $env:ADR_STD_LOCALAPPDATA } else { $env:LOCALAPPDATA }
$RoamApp   = if ($env:ADR_STD_APPDATA) { $env:ADR_STD_APPDATA } else { $env:APPDATA }
$DataDir   = Join-Path $LocalApp 'adr-std'
$BinDir    = Join-Path $DataDir 'bin'
$ConfigDir = Join-Path $RoamApp 'adr-std'
$StateFile = Join-Path $ConfigDir 'state'
# Config global do ADR-0001 (nível 4): a mesma que adr_cli.py (read_path_field) lê. Arquivo separado
# do estado da skill; só o campo `path` vive aqui, no formato `path: <valor>`.
$ConfigFile = Join-Path $ConfigDir 'config'
$SharedDir = '.agents/skills'
$SkillName = 'adr-std'
$Marker    = '.installed-by-adr-std'

if ($env:ADR_STD_SOURCE) {
    $Src = $env:ADR_STD_SOURCE
} elseif (Test-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'agents.tsv')) {
    $Src = Split-Path -Parent $PSScriptRoot
} else {
    $Src = $DataDir
}

# --- utilitários --------------------------------------------------------------

function Write-Err([string]$Message) { [Console]::Error.WriteLine("adr-std: $Message") }
function Stop-AdrStd([int]$Code, [string]$Message) { Write-Err $Message; exit $Code }

function Get-AdrStdVersion {
    $f = Join-Path $Src 'VERSION'
    if (Test-Path $f) { (Get-Content -Raw $f).Trim() } else { 'desconhecida' }
}

function ConvertTo-LocalPath([string]$Base, [string]$Relative) {
    Join-Path $Base ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Get-AgentRow {
    $f = Join-Path $Src 'agents.tsv'
    if (-not (Test-Path $f)) { Stop-AdrStd 1 "agents.tsv não encontrado em $Src" }
    Get-Content $f -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
        $c = $_ -split "`t"
        [pscustomobject]@{ Id = $c[0]; Name = $c[1]; Detect = $c[2]; Dir = $c[3]; Shared = $c[4] }
    }
}

function Get-Agent([string]$Id) { Get-AgentRow | Where-Object { $_.Id -eq $Id } | Select-Object -First 1 }
function Test-Agent([string]$Id) { $null -ne (Get-Agent $Id) }
function Test-Detected([string]$Id) {
    $a = Get-Agent $Id
    Test-Path (ConvertTo-LocalPath $UserHome $a.Detect)
}
function Get-DetectedId { Get-AgentRow | Where-Object { Test-Detected $_.Id } | ForEach-Object { $_.Id } }

function Get-CommandRow {
    $f = Join-Path $Src 'commands.tsv'
    if (-not (Test-Path $f)) { return @() }
    Get-Content $f -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
        $c = $_ -split "`t"
        [pscustomobject]@{ Action = $c[0]; Description = $c[1] }
    }
}

function Get-CommandTargetRow {
    $f = Join-Path $Src 'command_targets.tsv'
    if (-not (Test-Path $f)) { return @() }
    Get-Content $f -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
        $c = $_ -split "`t"
        [pscustomobject]@{ Id = $c[0]; Dir = $c[1]; Ext = $c[2]; ArgVar = $c[3] }
    }
}

function Get-CommandTarget([string]$Id) { Get-CommandTargetRow | Where-Object { $_.Id -eq $Id } | Select-Object -First 1 }

function Get-CommandMarkerLine([string]$Ext) {
    if ($Ext -eq 'toml') { return '# adr-std: gerado automaticamente; não editar à mão' }
    return '<!-- adr-std: gerado automaticamente; não editar à mão -->'
}

function Test-CommandOwnedBySelf([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    (Get-Content -Raw -LiteralPath $Path) -match 'adr-std: gerado automaticamente'
}

function Get-CommandFileContent([string]$Action, [string]$Description, [string]$Ext, [string]$ArgVar) {
    $marker = Get-CommandMarkerLine $Ext
    switch ($Ext) {
        'toml'   { "$marker`ndescription = `"$Description`"`nprompt = `"`"`"`nUse a skill adr-std, ação `"$Action`", com estes argumentos: $ArgVar`n`"`"`"`n" }
        'prompt' { "---`nname: adr-std-$Action`ndescription: $Description`n---`n$marker`nUse a skill adr-std, ação `"$Action`", com estes argumentos: $ArgVar`n" }
        default  { "---`ndescription: $Description`n---`n$marker`nUse a skill adr-std, ação `"$Action`", com estes argumentos: $ArgVar`n" }
    }
}

# Linhas de agent_launch.tsv: id, binário e flag do pedido ("-" = argumento posicional).
function Get-LaunchRow {
    $f = Join-Path $Src 'agent_launch.tsv'
    if (-not (Test-Path $f)) { return }
    foreach ($l in Get-Content $f -Encoding UTF8) {
        if ($l -and -not $l.StartsWith('#')) {
            $c = $l -split "`t"
            [pscustomobject]@{ Id = $c[0]; Bin = $c[1]; Flag = $c[2] }
        }
    }
}
function Get-Launch([string]$Id) { Get-LaunchRow | Where-Object { $_.Id -eq $Id } | Select-Object -First 1 }
function Test-Launchable([string]$Id) { $null -ne (Get-Launch $Id) }
function Get-LaunchableText { (Get-LaunchRow | ForEach-Object { $_.Id }) -join ' ' }

# Agentes com a skill instalada (estado) que abrem pelo terminal.
function Get-EligibleId { Get-StateAgent | ForEach-Object { $_.Id } | Where-Object { Test-Launchable $_ } }

# Termo sem espaço, com 4+ letras, parecido com o nome de um agente → id (ou vazio).
function Find-SimilarLaunchTerm([string]$Term) {
    if ($Term.Length -lt 4 -or $Term -match '\s') { return '' }
    foreach ($a in Get-AgentRow) { if ($a.Id.Contains($Term)) { return $a.Id } }
    return ''
}

function Test-Interactive {
    $null -ne $env:ADR_STD_ANSWER -or ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected)
}

function Find-SimilarAgent([string]$Term) {
    foreach ($a in Get-AgentRow) { if ($a.Id -like "*$Term*") { return $a.Id } }
    return ''
}

function Get-TargetFor([string]$Id) {
    $a = Get-Agent $Id
    if ($Id -eq 'universal' -or $a.Shared -eq 'sim') {
        Join-Path (ConvertTo-LocalPath $UserHome $SharedDir) $SkillName
    } else {
        Join-Path (ConvertTo-LocalPath $UserHome $a.Dir) $SkillName
    }
}

# --- estado (linhas: chave<TAB>valor) ------------------------------------------

function Get-StateLine { if (Test-Path $StateFile) { @(Get-Content $StateFile -Encoding UTF8) } else { @() } }

function Save-StateLine([string[]]$Lines) {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    [IO.File]::WriteAllLines($StateFile, [string[]]$Lines, (New-Object Text.UTF8Encoding($false)))
}

function Get-State([string]$Key) {
    foreach ($l in Get-StateLine) { $c = $l -split "`t"; if ($c[0] -eq $Key) { return $c[1] } }
    return ''
}

function Set-State([string]$Key, [string]$Value) {
    $keep = @(Get-StateLine | Where-Object { ($_ -split "`t")[0] -ne $Key })
    Save-StateLine ($keep + "$Key`t$Value")
}

function Remove-State([string]$Key) {
    Save-StateLine @(Get-StateLine | Where-Object { ($_ -split "`t")[0] -ne $Key })
}

function Get-StateAgent {
    foreach ($l in Get-StateLine) {
        $c = $l -split "`t"
        if ($c[0] -eq 'agent') { [pscustomobject]@{ Id = $c[1]; Dest = $c[2] } }
    }
}

function Add-StateAgent([string]$Id, [string]$Dest) {
    $keep = @(Get-StateLine | Where-Object { $c = $_ -split "`t"; -not ($c[0] -eq 'agent' -and $c[1] -eq $Id) })
    Save-StateLine ($keep + "agent`t$Id`t$Dest")
}

function Remove-StateAgent([string]$Id) {
    if (-not (Test-Path $StateFile)) { return }
    $keep = @(Get-StateLine | Where-Object { $c = $_ -split "`t"; -not ($c[0] -eq 'agent' -and $c[1] -eq $Id) })
    Save-StateLine $keep
}

function Add-StateCommand([string]$Id, [string]$Path) {
    $keep = @(Get-StateLine | Where-Object { $c = $_ -split "`t"; -not ($c[0] -eq 'command' -and $c[1] -eq $Id -and $c[2] -eq $Path) })
    Save-StateLine ($keep + "command`t$Id`t$Path")
}

function Remove-StateCommandsFor([string]$Id) {
    foreach ($l in Get-StateLine) {
        $c = $l -split "`t"
        if ($c[0] -eq 'command' -and $c[1] -eq $Id -and (Test-CommandOwnedBySelf $c[2])) {
            Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $c[2]
        }
    }
    if (-not (Test-Path $StateFile)) { return }
    $keep = @(Get-StateLine | Where-Object { $c = $_ -split "`t"; -not ($c[0] -eq 'command' -and $c[1] -eq $Id) })
    Save-StateLine $keep
}

# --- argumentos ---------------------------------------------------------------

$script:Agents = @()
$script:All = $false
$script:Link = $false
$script:Dry = $false
$script:NoCommands = $false
$script:NoMigrate = $false
$script:ReqVersion = ''

function Read-Option([string[]]$Tokens) {
    $script:Agents = @(); $script:All = $false; $script:Link = $false; $script:Dry = $false; $script:NoCommands = $false; $script:NoMigrate = $false; $script:ReqVersion = ''
    $i = 0
    while ($i -lt $Tokens.Count) {
        $t = $Tokens[$i]; $i++
        switch -Regex ($t) {
            '^--agent$'    { continue }
            '^--agent=(.+)$' { $Tokens = @($Matches[1]) + $Tokens[$i..($Tokens.Count)]; $i = 0; continue }
            '^--all$'      { $script:All = $true; continue }
            '^--link$'     { $script:Link = $true; continue }
            '^--dry-run$'  { $script:Dry = $true; continue }
            '^--no-commands$' { $script:NoCommands = $true; continue }
            '^--no-migrate$' { $script:NoMigrate = $true; continue }
            '^--version$'  { if ($i -lt $Tokens.Count) { $script:ReqVersion = $Tokens[$i]; $i++ }; continue }
            '^--'          { Stop-AdrStd 2 "opção desconhecida: $t" }
            default {
                foreach ($part in ($t -split ',')) {
                    if ($part -eq '') { continue }
                    if (Test-Agent $part) { $script:Agents += $part }
                    else {
                        $s = Find-SimilarAgent $part
                        if ($s) { Stop-AdrStd 2 "agente desconhecido: $part (quis dizer ${s}?)" }
                        Stop-AdrStd 2 "agente desconhecido: $part. Veja: adr-std agents"
                    }
                }
            }
        }
    }
}

# --- instalação ---------------------------------------------------------------

function Test-OwnedBySelf([string]$Dest) {
    $registered = @(Get-StateAgent | ForEach-Object { $_.Dest })
    if ($registered -notcontains $Dest) { return $false }
    $item = Get-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $false }
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = @($item.Target)[0]
        return ($target -eq (Join-Path $Src 'skill')) -or ($target -eq (Join-Path $DataDir 'skill'))
    }
    return (Test-Path (Join-Path $Dest $Marker))
}

function Remove-Target([string]$Dest) {
    $item = Get-Item -LiteralPath $Dest -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $item.Delete() }
    else { Remove-Item -LiteralPath $Dest -Recurse -Force }
}

function Install-To([string]$Dest) {
    if ((Test-Path -LiteralPath $Dest) -or (Get-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue)) {
        if (Test-OwnedBySelf $Dest) { Remove-Target $Dest }
        else {
            Write-Err "$Dest já existe e não foi instalada pelo adr-std; nada foi alterado. Remova ou renomeie a pasta e tente de novo."
            exit 4
        }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dest) | Out-Null
    if ($script:Link) {
        New-Item -ItemType Junction -Path $Dest -Target (Join-Path $Src 'skill') | Out-Null
    } else {
        $tmp = "$Dest.tmp"
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        Copy-Item -Recurse -Path (Join-Path $Src 'skill') -Destination $tmp
        Set-Content -Path (Join-Path $tmp $Marker) -Value ("adr-std {0} instalado em {1}" -f (Get-AdrStdVersion), (Get-Date -Format 'yyyy-MM-dd'))
        Move-Item -Path $tmp -Destination $Dest
    }
    Write-Host ("  ✔ adr-std {0} → {1}" -f (Get-AdrStdVersion), $Dest)
}

function Read-Answer([string]$Prompt) {
    if ($null -ne $env:ADR_STD_ANSWER) { Write-Host "$Prompt$($env:ADR_STD_ANSWER)"; return $env:ADR_STD_ANSWER }
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) { return (Read-Host $Prompt) }
    return $null
}

function Select-Agent {
    $found = @(Get-DetectedId)
    if ($found.Count -eq 0) { Stop-AdrStd 3 'nenhum agente encontrado neste computador. Indique com --agent (veja: adr-std agents)' }
    Write-Host 'Agentes encontrados neste computador:'
    for ($n = 0; $n -lt $found.Count; $n++) {
        Write-Host ("  {0}) {1,-15} ~/{2}" -f ($n + 1), $found[$n], (Get-Agent $found[$n]).Dir)
    }
    $line = Read-Answer 'Em quais instalar? (ex.: 1 3, ou "todos"): '
    if ($null -eq $line) { Stop-AdrStd 3 'sem terminal para o menu. Indique os agentes com --agent (ex.: --agent claude-code) ou use --all' }
    if ($line.Trim() -eq 'todos') { return $found }
    $chosen = @()
    foreach ($tok in ($line -split '[ ,]+' | Where-Object { $_ })) {
        if ($tok -match '^\d+$' -and [int]$tok -ge 1 -and [int]$tok -le $found.Count) { $chosen += $found[[int]$tok - 1] }
        else { Stop-AdrStd 2 "escolha inválida: $tok" }
    }
    if ($chosen.Count -eq 0) { Stop-AdrStd 3 'nenhum agente escolhido. Indique os agentes com --agent (ex.: --agent claude-code) ou use --all' }
    return $chosen
}

function Install-Command([string[]]$Ids) {
    if ($script:NoCommands) { return }
    $actions = @(Get-CommandRow)
    if ($actions.Count -eq 0) { return }
    foreach ($id in $Ids) {
        $target = Get-CommandTarget $id
        if ($null -eq $target) { continue }
        $destDir = ConvertTo-LocalPath $UserHome $target.Dir
        if (-not $script:Dry) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
        foreach ($a in $actions) {
            $file = Join-Path $destDir "adr-std-$($a.Action).$($target.Ext)"
            if ((Test-Path -LiteralPath $file) -and -not (Test-CommandOwnedBySelf $file)) {
                Write-Host "  ! $file já existe e não foi gerado pelo adr-std; mantido"
                continue
            }
            if ($script:Dry) { Write-Host "  (simulação) criaria $file"; continue }
            Set-Content -LiteralPath $file -NoNewline -Value (Get-CommandFileContent $a.Action $a.Description $target.Ext $target.ArgVar)
            Add-StateCommand $id $file
        }
    }
}

function Invoke-Install([string[]]$Tokens) {
    Read-Option $Tokens
    if (-not (Test-Path (Join-Path $Src 'skill/SKILL.md'))) { Stop-AdrStd 1 "skill não encontrada em $(Join-Path $Src 'skill')" }
    $ids = @($script:Agents)
    if ($script:All) {
        $ids = @(Get-DetectedId)
        if ($ids.Count -eq 0) { Stop-AdrStd 3 'nenhum agente encontrado neste computador. Veja: adr-std agents' }
    }
    if ($ids.Count -eq 0) { $ids = @(Select-Agent) }
    $done = @{}
    foreach ($id in $ids) {
        $dest = Get-TargetFor $id
        if (-not (Test-Detected $id)) { Write-Host "  ! $id não foi encontrado neste computador; instalando mesmo assim" }
        if (-not $done.ContainsKey($dest)) {
            $done[$dest] = $true
            if ($script:Dry) { Write-Host ("  (simulação) instalaria adr-std {0} em {1}" -f (Get-AdrStdVersion), $dest) }
            else { Install-To $dest }
        }
        if (-not $script:Dry) { Add-StateAgent $id $dest }
    }
    Install-Command $ids
    if (-not $script:Dry) {
        Set-State 'version' (Get-AdrStdVersion)
        Set-State 'mode' $(if ($script:Link) { 'link' } else { 'copy' })
        Write-Host 'Pronto. Abra uma nova sessão do agente para carregar a skill.'
    }
}

function Invoke-Uninstall([string[]]$Tokens) {
    Read-Option $Tokens
    $ids = @($script:Agents)
    if ($ids.Count -eq 0) { $ids = @(Get-StateAgent | ForEach-Object { $_.Id }) }
    if ($ids.Count -eq 0) { Write-Host 'Nada a remover: nenhum agente registrado.'; return }
    foreach ($id in $ids) {
        $entry = Get-StateAgent | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if ($null -eq $entry) { Write-Host "  • $id não está registrado; nada a remover"; continue }
        $dest = $entry.Dest
        $others = @(Get-StateAgent | Where-Object { $_.Dest -eq $dest -and $_.Id -ne $id })
        if ($others.Count -gt 0) { Write-Host "  • $dest continua em uso por outro agente; mantida" }
        elseif (-not (Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue)) { Write-Host "  • $dest já não existe" }
        elseif (Test-OwnedBySelf $dest) {
            if ($script:Dry) { Write-Host "  (simulação) removeria $dest" }
            else { Remove-Target $dest; Write-Host "  ✔ removida $dest" }
        }
        else { Write-Host "  ! $dest não foi instalada pelo adr-std; mantida" }
        if (-not $script:Dry) { Remove-StateAgent $id; Remove-StateCommandsFor $id }
    }
}

function Invoke-Status {
    $ver = Get-State 'version'
    if (-not $ver -or @(Get-StateAgent).Count -eq 0) {
        Write-Host ("adr-std: skill não instalada (comando {0}). Instale com: adr-std install" -f (Get-AdrStdVersion)); return
    }
    Write-Host ("adr-std: skill instalada na versão {0} (comando {1}); modo {2}" -f $ver, (Get-AdrStdVersion), (Get-State 'mode'))
    foreach ($e in Get-StateAgent) {
        $ok = (Test-Path (Join-Path $e.Dest 'SKILL.md'))
        $note = if ($ok) { 'íntegra' } else { 'danificada (pasta ausente ou incompleta)' }
        Write-Host ("  {0,-15} {1}  [{2}]" -f $e.Id, $e.Dest, $note)
    }
}

function Invoke-Agent {
    Write-Host ("  {0,-15} {1,-27} {2,-30} {3}" -f 'AGENTE', 'NOME', 'PASTA DE SKILLS', 'NESTE COMPUTADOR')
    foreach ($a in Get-AgentRow) {
        $mark = if (Test-Detected $a.Id) { '✔ encontrado' } else { '-' }
        Write-Host ("  {0,-15} {1,-27} {2,-30} {3}" -f $a.Id, $a.Name, "~/$($a.Dir)", $mark)
    }
}

# Roda um script Python da skill; sem Python 3, avisa e indica o checklist manual (código 6).
function Get-Python3 {
    foreach ($cand in 'python3', 'python', 'py') {
        $found = Get-Command $cand -ErrorAction SilentlyContinue
        if ($found) {
            & $found.Source -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' 2>$null
            if ($LASTEXITCODE -eq 0) { return $found.Source }
        }
    }
    return $null
}

function Invoke-PythonScript([string]$ScriptName, [string]$Command, [string[]]$Tokens) {
    $py = Get-Python3
    if (-not $py) {
        Stop-AdrStd 6 ("o comando {0} precisa de Python 3, que não foi encontrado. Instale o Python 3 ou aplique o checklist manualmente: {1}" -f $Command, (Join-Path $Src 'skill/references/checklist.md'))
    }
    $script = Join-Path $Src "skill/scripts/$ScriptName"
    if (-not (Test-Path $script)) { Stop-AdrStd 1 "$ScriptName não encontrado em $(Join-Path $Src 'skill/scripts')" }
    & $py $script @Tokens
    exit $LASTEXITCODE
}

function Invoke-Check([string[]]$Tokens) {
    if ($Tokens.Count -eq 0) { Stop-AdrStd 2 'uso: adr-std check <arquivo-ou-pasta> [--name-pattern REGEX]' }
    Invoke-PythonScript 'check_adr.py' 'check' $Tokens
}

# new, list, link e organize: lógica em skill/scripts/adr_cli.py
function Invoke-Mechanical([string]$Command, [string[]]$Tokens) {
    Invoke-PythonScript 'adr_cli.py' $Command (@($Command) + $Tokens)
}

# migrate: lógica em skill/scripts/migrate_numbering.py (plano por omissão; --apply aplica)
function Invoke-Migrate([string[]]$Tokens) {
    Invoke-PythonScript 'migrate_numbering.py' 'migrate' $Tokens
}

function Invoke-Update([string[]]$Tokens) {
    Read-Option $Tokens
    $ids = @(Get-StateAgent | ForEach-Object { $_.Id })
    foreach ($id in $script:Agents) { if ($ids -notcontains $id) { $ids += $id } }
    if ($ids.Count -eq 0) { Stop-AdrStd 3 'nenhum agente registrado. Instale primeiro com: adr-std install' }
    $installer = Join-Path $DataDir 'install.ps1'
    if (-not (Test-Path $installer)) { $installer = Join-Path $Src 'install.ps1' }
    if (-not (Test-Path $installer)) { Stop-AdrStd 1 'instalador não encontrado; reinstale o adr-std' }
    if ($script:Dry) {
        $v = if ($script:ReqVersion) { $script:ReqVersion } else { 'para a última versão' }
        Write-Host ("  (simulação) atualizaria {0} nos agentes: {1}" -f $v, ($ids -join ' ')); return
    }
    $env:ADR_STD_REMOTE = '1'
    $opts = @()
    if ($script:ReqVersion) { $opts += @('--version', $script:ReqVersion) }
    if ($script:Link) { $opts += '--link' }
    $ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    & $ps -NoProfile -ExecutionPolicy Bypass -File $installer @opts --agent @ids
    $rc = $LASTEXITCODE
    if ($rc -ne 0) { exit $rc }
    if (-not $script:NoMigrate) { Invoke-MaybeMigrate }
    exit 0
}

# Roda migrate_numbering.py no diretório atual e devolve a saída e o código (nunca encerra o comando).
function Invoke-MigrateStep([string]$Py, [string]$Script, [string[]]$Tokens) {
    $oldEnc = [Console]::OutputEncoding
    $oldPyEnc = $env:PYTHONIOENCODING
    try {
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        $env:PYTHONIOENCODING = 'utf-8'
        $out = (& $Py $Script @Tokens 2>&1 | Out-String).TrimEnd()
        $code = $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $oldEnc
        if ($null -eq $oldPyEnc) { Remove-Item Env:PYTHONIOENCODING -ErrorAction SilentlyContinue } else { $env:PYTHONIOENCODING = $oldPyEnc }
    }
    [pscustomobject]@{ Output = $out; Code = $code }
}

# Gancho do update (v2.0): mostra o plano de migração dos ADRs do diretório atual e só aplica com
# confirmação interativa (SEG-06). Qualquer falha vira aviso e não altera o código de saída do update.
function Invoke-MaybeMigrate {
    try {
        $py = Get-Python3
        if (-not $py) {
            Write-Host 'aviso: a skill foi atualizada, mas a migração precisa de Python 3, que não foi encontrado. Quando puder, rode: adr-std migrate'
            return
        }
        $script = Join-Path $Src 'skill/scripts/migrate_numbering.py'
        if (-not (Test-Path $script)) {
            Write-Host "aviso: a skill foi atualizada, mas migrate_numbering.py não foi encontrado em $(Join-Path $Src 'skill/scripts')."
            return
        }
        $r = Invoke-MigrateStep $py $script @()
        if ($r.Code -ne 0) {
            Write-Host "aviso: a skill foi atualizada, mas não foi possível calcular o plano de migração (código $($r.Code)):"
            Write-Host $r.Output
            Write-Host 'Quando puder, rode: adr-std migrate'
            return
        }
        $first = ($r.Output -split "`n" | Select-Object -First 1)
        if ($first -notmatch 'plano de migração') { Write-Host 'migração: nada a fazer'; return }
        Write-Host $r.Output
        $ans = Read-Answer 'Aplicar a migração? [s/N] '
        if ($null -eq $ans) { Write-Host 'adr-std migrate --apply'; return }
        if ($ans -cmatch '^[sS]$') {
            $a = Invoke-MigrateStep $py $script @('--apply')
            Write-Host $a.Output
            if ($a.Code -ne 0) { Write-Host "aviso: a migração não foi concluída (código $($a.Code)); a skill continua atualizada. Veja a mensagem acima e rode: adr-std migrate" }
        } else {
            Write-Host 'Migração não aplicada. Para aplicar depois: adr-std migrate --apply'
        }
    } catch {
        Write-Host "aviso: a skill foi atualizada, mas a etapa de migração falhou: $($_.Exception.Message)"
    }
}

function Invoke-SelfUninstall([string[]]$Tokens) {
    Read-Option $Tokens
    $pathEntry = Get-State 'path_entry'
    if ($script:Dry) {
        Write-Host "  (simulação) removeria a skill dos agentes registrados, $BinDir, $DataDir e $ConfigDir"
        if ($pathEntry) { Write-Host "  (simulação) removeria $pathEntry do PATH do usuário" }
        return
    }
    Invoke-Uninstall @()
    if ($pathEntry -and -not $env:ADR_STD_NO_PATH) {
        $current = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($current) {
            $parts = @($current -split ';' | Where-Object { $_ -and $_ -ne $pathEntry })
            [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
            Write-Host "  ✔ $pathEntry removido do PATH do usuário"
        }
    }
    # O comando está em execução dentro de $DataDir; remove o que puder e agenda o resto.
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $ConfigDir
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $DataDir 'skill')
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $DataDir 'agents.tsv'), (Join-Path $DataDir 'VERSION'), (Join-Path $DataDir 'install.ps1'), (Join-Path $DataDir 'README.md')
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BinDir 'adr-std.cmd')
    Write-Host 'adr-std removido deste computador.'
}

# --- comandos de conversa (v1.3): abrem um agente com a skill ------------------------

function Stop-UnknownLaunchAgent([string]$Name) {
    if (Test-Agent $Name) { Stop-AdrStd 2 "$Name não abre pelo terminal com um pedido inicial. Agentes que abrem: $(Get-LaunchableText)" }
    $sim = Find-SimilarLaunchTerm $Name
    if ($sim) { Stop-AdrStd 2 "agente desconhecido: $Name (quis dizer ${sim}?)" }
    Stop-AdrStd 2 "agente desconhecido: $Name. Agentes que abrem: $(Get-LaunchableText)"
}

# Devolve Agent, Opts e Text. O primeiro termo só é agente se for exatamente um nome da lista e vier seguido da descrição.
function Read-ConverseArg([string]$Action, [string[]]$Tokens) {
    $agent = ''; $opts = @(); $words = @()
    $takesOpts = $Action -in 'create', 'supersede'
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        $t = $Tokens[$i]
        if ($t -eq '--agent') {
            if ($i + 1 -ge $Tokens.Count) { Stop-AdrStd 2 '--agent pede o nome do agente' }
            $agent = $Tokens[++$i]
        } elseif ($t.StartsWith('--agent=')) {
            $agent = $t.Substring(8)
        } elseif ($t -in '--ask', '-a') {
            if (-not $takesOpts) { Stop-AdrStd 2 "$t só vale em create e supersede" }
            if ($i + 1 -ge $Tokens.Count -or $Tokens[$i + 1] -notmatch '^\d+$') { Stop-AdrStd 2 "$t pede um número de 1 a 10" }
            $opts += '--ask'; $opts += $Tokens[++$i]
        } elseif ($t -in '--quick', '-k') {
            if (-not $takesOpts) { Stop-AdrStd 2 "$t só vale em create e supersede" }
            $opts += '--quick'
        } elseif ($t -eq '--') {
            if ($i + 1 -lt $Tokens.Count) { $words += $Tokens[($i + 1)..($Tokens.Count - 1)] }
            break
        } elseif ($t.StartsWith('-')) {
            Stop-AdrStd 2 "opção desconhecida: $t"
        } else {
            $words += $t
        }
    }
    if ($words.Count -gt 1) {
        $first = $words[0]
        if (Test-Agent $first) {
            if ($agent -and $agent -ne $first) { Stop-AdrStd 2 "agente indicado duas vezes: $agent e $first" }
            $agent = $first; $words = @($words[1..($words.Count - 1)])
        } else {
            $sim = Find-SimilarLaunchTerm $first
            if ($sim) { Stop-AdrStd 2 "`"$first`" parece um agente (quis dizer ${sim}?). Use --agent $sim ou coloque a descrição entre aspas" }
        }
    }
    if ($agent -and -not (Test-Launchable $agent)) { Stop-UnknownLaunchAgent $agent }
    [pscustomobject]@{ Agent = $agent; Opts = $opts; Text = $words }
}

# Escolhe o agente: indicado, padrão ou menu (com o último usado pré-selecionado).
function Select-LaunchAgent([string]$Agent) {
    if ($Agent) { return $Agent }
    $def = Get-State 'default_agent'
    if ($def -and (Test-Launchable $def)) {
        Write-Host "adr-std: usando o agente padrão $def (mude com: adr-std config agent)"
        return $def
    }
    if (-not (Test-Interactive)) {
        Stop-AdrStd 3 'sem terminal interativo para escolher o agente. Indique com --agent (ex.: --agent claude-code) ou defina um padrão: adr-std config agent <nome>'
    }
    $found = @(Get-EligibleId)
    if ($found.Count -eq 0) {
        Stop-AdrStd 3 "nenhum agente com a skill instalada abre pelo terminal. Instale com: adr-std install <agente> (agentes: $(Get-LaunchableText))"
    }
    $last = Get-State 'last_agent'
    $pre = 1
    Write-Host 'Agentes com a skill instalada que abrem pelo terminal:'
    for ($n = 0; $n -lt $found.Count; $n++) {
        $mark = ''
        if ($found[$n] -eq $last) { $pre = $n + 1; $mark = '  (último usado)' }
        Write-Host ("  {0}) {1}{2}" -f ($n + 1), $found[$n], $mark)
    }
    $line = Read-Answer ("Qual abrir? [{0}]: " -f $pre)
    $line = if ($line) { $line.Trim() } else { '' }
    if (-not $line) { $line = [string]$pre }
    if ($line -match '^\d+$' -and [int]$line -ge 1 -and [int]$line -le $found.Count) { return $found[[int]$line - 1] }
    Stop-AdrStd 2 "escolha inválida: $line"
}

# Abre o agente com o pedido inicial como UM argumento (sem Invoke-Expression: a descrição nunca vira comando).
function Start-LaunchAgent([string]$Id, [string]$Action, $Parsed) {
    $row = Get-Launch $Id
    $cmd = Get-Command $row.Bin -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { Stop-AdrStd 5 "o agente $Id não está disponível: o programa '$($row.Bin)' não foi encontrado no PATH" }
    if (-not ((Get-StateAgent | ForEach-Object { $_.Id }) -contains $Id)) {
        Write-Host "  ! a skill adr-std não está registrada para $Id; instale com: adr-std install $Id"
    }
    $args1 = (@($Parsed.Opts) + @($Parsed.Text)) -join ' '
    $request = "Use a skill adr-std, ação `"$Action`", com estes argumentos: $args1".TrimEnd()
    # Windows PowerShell 5.1 e PowerShell < 7.3 repassam aspas internas sem escape ao programa nativo.
    $sent = if ($PSVersionTable.PSVersion -lt [version]'7.3') { $request -replace '"', '\"' } else { $request }
    Set-State 'last_agent' $Id
    if ($row.Flag -eq '-') { & $cmd.Source $sent } else { & $cmd.Source $row.Flag $sent }
    exit $LASTEXITCODE
}

function Invoke-Converse([string]$Action, [string[]]$Tokens) {
    $parsed = Read-ConverseArg $Action $Tokens
    if ($Action -eq 'ask' -and @($parsed.Text).Count -eq 0) { Stop-AdrStd 2 'uso: adr-std ask [agente] <pergunta>' }
    $id = Select-LaunchAgent $parsed.Agent
    Start-LaunchAgent $id $Action $parsed
}

# Campo `path` da config global (ADR-0001, nível 4). Grava em $ConfigFile no formato `path: <valor>`,
# que read_path_field (adr_cli.py) lê. Preserva as demais linhas do arquivo, se houver.
function Get-ConfigLine { if (Test-Path $ConfigFile) { @(Get-Content $ConfigFile -Encoding UTF8) } else { @() } }

function Get-ConfigPath {
    foreach ($l in Get-ConfigLine) {
        if ($l -match '^path\s*[:=]\s*(.+?)\s*$') { return $Matches[1] }
    }
    return ''
}

function Set-ConfigPath([string]$Value) {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    $keep = @(Get-ConfigLine | Where-Object { $_ -notmatch '^path\s*[:=]' })
    [IO.File]::WriteAllLines($ConfigFile, [string[]]($keep + "path: $Value"), (New-Object Text.UTF8Encoding($false)))
}

function Remove-ConfigPath {
    if (-not (Test-Path $ConfigFile)) { return }
    $keep = @(Get-ConfigLine | Where-Object { $_ -notmatch '^path\s*[:=]' })
    [IO.File]::WriteAllLines($ConfigFile, [string[]]$keep, (New-Object Text.UTF8Encoding($false)))
}

function Invoke-Config([string[]]$Tokens) {
    $sub = if ($Tokens.Count -gt 0) { $Tokens[0] } else { '' }
    $rest = if ($Tokens.Count -gt 1) { $Tokens[1..($Tokens.Count - 1)] } else { @() }
    switch ($sub) {
        'agent' { Invoke-ConfigAgent $rest }
        'path'  { Invoke-ConfigPath $rest }
        default { Stop-AdrStd 2 'uso: adr-std config <agent|path> ...' }
    }
}

function Invoke-ConfigAgent([string[]]$Tokens) {
    $arg = if ($Tokens.Count -gt 0) { $Tokens[0] } else { '' }
    if (-not $arg) {
        $cur = Get-State 'default_agent'
        if ($cur) { Write-Host "agente padrão: $cur" } else { Write-Host 'nenhum agente padrão definido' }
    } elseif ($arg -eq '--unset') {
        Remove-State 'default_agent'
        Write-Host 'agente padrão removido'
    } elseif ($arg.StartsWith('-')) {
        Stop-AdrStd 2 "opção desconhecida: $arg"
    } else {
        if (-not (Test-Launchable $arg)) { Stop-UnknownLaunchAgent $arg }
        Set-State 'default_agent' $arg
        Write-Host "agente padrão: $arg"
    }
}

function Invoke-ConfigPath([string[]]$Tokens) {
    $arg = if ($Tokens.Count -gt 0) { $Tokens[0] } else { '' }
    if (-not $arg) {
        $cur = Get-ConfigPath
        if ($cur) { Write-Host "pasta de ADRs: $cur" } else { Write-Host 'nenhuma pasta de ADRs definida (usando o padrão docs/architecture/ADR)' }
    } elseif ($arg -eq '--unset') {
        if (Get-ConfigPath) { Remove-ConfigPath; Write-Host 'pasta de ADRs removida' } else { Write-Host 'nenhuma pasta de ADRs definida' }
    } elseif ($arg.StartsWith('-')) {
        Stop-AdrStd 2 "opção desconhecida: $arg"
    } else {
        Set-ConfigPath $arg
        Write-Host "pasta de ADRs: $arg"
    }
}

function Show-Help {
    $ids = (Get-AgentRow | ForEach-Object { $_.Id }) -join ' '
    @"
adr-std $(Get-AdrStdVersion) — gerencia a skill adr-std (ADRs segundo a ISO/IEC/IEEE 42010:2022)

Uso: adr-std <comando> [opções]

Comandos:
  install [agentes...]   Instala a skill (sem agentes: mostra um menu)
      --agent a b        Agentes (separados por espaço ou vírgula); também aceita os nomes direto
      --all              Todos os agentes encontrados
      --link             Junção para a fonte em vez de cópia (desenvolvimento)
      --dry-run          Mostra o que faria, sem alterar nada
      --version vX.Y.Z   Versão específica
  update                 Atualiza nos agentes já registrados (--agent inclui mais agentes)
      --no-migrate       Não calcula nem mostra o plano de migração dos ADRs (por omissão o update mostra o plano
                         no diretório atual e só aplica com sua confirmação em terminal)
  uninstall [agentes...] Remove a skill (sem agentes: de todos)
  self-uninstall         Remove tudo, inclusive este comando
  status                 Versão, agentes e integridade
  agents                 Agentes suportados e os encontrados neste computador
  check <arquivo|pasta>  Verifica ADRs (precisa de Python 3)
  new <título>           Cria o esqueleto de um ADR, sem perguntas (Python 3)
  list                   Lista os ADRs da pasta (Python 3)
  link <A> <tipo> <B>    Registra uma relação entre dois ADRs, nos dois lados (Python 3)
  organize --dry-run     Mostra o plano de renumeração, sem alterar nada (Python 3)
                         (new, list, link e organize aceitam --path PASTA e --name-pattern REGEX)
  migrate [--apply]      Migra ADRs com zeros à esquerda (0001-x.md) para o padrão sem zeros; só mostra o plano sem --apply (Python 3)
                         (aceita --path PASTA, --root RAIZ e --exclude GLOB, repetível, para proteger arquivos)
  create [agente] <descrição>   Abre um agente para criar um ADR em conversa (aceita --ask N e --quick)
  supersede [agente] <ADR>      Abre um agente para criar o ADR que substitui outro (aceita --ask N e --quick)
  review [agente] <pasta>       Abre um agente para revisar ADRs
  audit [agente]                Abre um agente para auditar a descrição de arquitetura
  ask [agente] <pergunta>       Abre um agente para tirar dúvidas sobre a norma
                         Escolha do agente: indicado no comando (nome ou --agent), padrão, ou menu com o último usado
  config agent [nome]    Mostra, define ou remove (--unset) o agente padrão dos comandos acima
  config path [pasta]    Mostra, define ou remove (--unset) a pasta de ADRs na config global
  version                Mostra a versão
  help                   Mostra esta ajuda

Agentes: $ids
"@ | Write-Host
}

# --- despacho -----------------------------------------------------------------

$cmd = if ($args.Count -gt 0) { [string]$args[0] } else { 'help' }
$rest = if ($args.Count -gt 1) { [string[]]$args[1..($args.Count - 1)] } else { [string[]]@() }

switch ($cmd) {
    { $_ -in 'version', '--version', '-v' } { Write-Host "adr-std $(Get-AdrStdVersion)" }
    { $_ -in 'help', '--help', '-h' }       { Show-Help }
    'agents'         { Invoke-Agent }
    'install'        { Invoke-Install $rest }
    'uninstall'      { Invoke-Uninstall $rest }
    'status'         { Invoke-Status }
    'check'          { Invoke-Check $rest }
    { $_ -in 'new', 'list', 'link', 'organize' } { Invoke-Mechanical $cmd $rest }
    'migrate'        { Invoke-Migrate $rest }
    { $_ -in 'create', 'supersede', 'review', 'audit', 'ask' } { Invoke-Converse $cmd $rest }
    'config'         { Invoke-Config $rest }
    'update'         { Invoke-Update $rest }
    'self-uninstall' { Invoke-SelfUninstall $rest }
    default {
        Write-Err "comando desconhecido: $cmd"
        Show-Help
        exit 2
    }
}
