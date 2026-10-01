# Instalador do adr-std (Windows).
#
# Instala o comando "adr-std" no seu usuário e depois executa "adr-std install".
# Não pede administrador e só escreve dentro do seu perfil.
#
# Uso:
#   .\install.ps1 [opções do adr-std install]     # ex.: .\install.ps1 --agent claude-code codex
#   irm https://raw.githubusercontent.com/dihcruz1/adr-std/main/install.ps1 | iex   # sem argumentos: menu
#
# Compatível com Windows PowerShell 5.1 e PowerShell 7+.

$ErrorActionPreference = 'Stop'

$LocalApp  = if ($env:ADR_STD_LOCALAPPDATA) { $env:ADR_STD_LOCALAPPDATA } else { $env:LOCALAPPDATA }
$RoamApp   = if ($env:ADR_STD_APPDATA) { $env:ADR_STD_APPDATA } else { $env:APPDATA }
$DataDir   = Join-Path $LocalApp 'adr-std'
$BinDir    = Join-Path $DataDir 'bin'
$ConfigDir = Join-Path $RoamApp 'adr-std'
$StateFile = Join-Path $ConfigDir 'state'
$BaseUrl   = if ($env:ADR_STD_BASE_URL) { $env:ADR_STD_BASE_URL } else { 'https://github.com/dihcruz1/adr-std' }

function Write-Err([string]$Message) { [Console]::Error.WriteLine("adr-std: $Message") }
function Stop-Install([int]$Code, [string]$Message) { Write-Err $Message; exit $Code }

# --version é do instalador (versão da release); os demais argumentos vão para "adr-std install".
$reqVersion = ''
$passArgs = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--version') { if ($i + 1 -lt $args.Count) { $reqVersion = $args[$i + 1]; $i++ } }
    else { $passArgs += $args[$i] }
}

# --- origem dos arquivos -----------------------------------------------------
# Modo local: arquivos ao lado do instalador. Modo remoto: baixa a release e confere o checksum.
# ADR_STD_REMOTE=1 força o modo remoto (usado pelo "adr-std update").

$here = if ($PSScriptRoot) { $PSScriptRoot } else { '' }
$local = ($here -ne '') -and (Test-Path (Join-Path $here 'skill/SKILL.md')) -and (Test-Path (Join-Path $here 'bin/adr-std.ps1'))

if ($local -and $env:ADR_STD_REMOTE -ne '1' -and -not $reqVersion) {
    $Src = $here
} else {
    $url = if ($reqVersion) { "$BaseUrl/releases/download/$reqVersion" } else { "$BaseUrl/releases/latest/download" }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("adr-std-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $shown = if ($reqVersion) { $reqVersion } else { 'a última versão' }
        Write-Host "Baixando $shown de $BaseUrl ..."
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "$url/adr-std.zip" -OutFile (Join-Path $tmp 'adr-std.zip')
            Invoke-WebRequest -UseBasicParsing -Uri "$url/adr-std.zip.sha256" -OutFile (Join-Path $tmp 'adr-std.zip.sha256')
        } catch {
            Stop-Install 5 'não consegui baixar o pacote'
        }
        $expected = ((Get-Content (Join-Path $tmp 'adr-std.zip.sha256') -TotalCount 1) -split '\s+')[0].ToLower()
        $actual = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $tmp 'adr-std.zip')).Hash.ToLower()
        if ($expected -ne $actual) { Stop-Install 5 'o checksum do pacote não confere; nada foi instalado.' }
        Expand-Archive -Path (Join-Path $tmp 'adr-std.zip') -DestinationPath (Join-Path $tmp 'pkg') -Force
        $Src = Join-Path $tmp 'pkg'
        if (-not (Test-Path (Join-Path $Src 'skill/SKILL.md'))) { Stop-Install 5 'pacote inválido: skill/SKILL.md não encontrado' }
        $installed = $true
    } catch {
        throw
    }
}

# --- cópia da fonte e do comando ---------------------------------------------

New-Item -ItemType Directory -Force -Path $DataDir, $BinDir, $ConfigDir | Out-Null
foreach ($d in 'skill') {
    $target = Join-Path $DataDir $d
    if (Test-Path $target) { Remove-Item -Recurse -Force $target }
    Copy-Item -Recurse -Path (Join-Path $Src $d) -Destination $target
}
foreach ($f in 'agents.tsv', 'commands.tsv', 'command_targets.tsv', 'VERSION', 'install.ps1', 'README.md') {
    $p = Join-Path $Src $f
    if (Test-Path $p) { Copy-Item -Force -Path $p -Destination $DataDir }
}
foreach ($f in 'adr-std.ps1', 'adr-std.cmd') {
    Copy-Item -Force -Path (Join-Path $Src "bin/$f") -Destination $BinDir
}
$version = (Get-Content -Raw (Join-Path $DataDir 'VERSION')).Trim()
Write-Host "  ✔ comando adr-std $version → $BinDir"

# --- PATH (só do usuário; pergunta antes) ------------------------------------

function Save-PathEntry([string]$Entry) {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    $lines = @()
    if (Test-Path $StateFile) { $lines = @(Get-Content $StateFile -Encoding UTF8 | Where-Object { ($_ -split "`t")[0] -ne 'path_entry' }) }
    $lines += "path_entry`t$Entry"
    [IO.File]::WriteAllLines($StateFile, [string[]]$lines, (New-Object Text.UTF8Encoding($false)))
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$already = $false
if ($userPath) { $already = @($userPath -split ';') -contains $BinDir }
if (-not $already -and -not $env:ADR_STD_NO_PATH) {
    Write-Host "A pasta $BinDir não está no PATH; sem isso o comando adr-std não será encontrado."
    $reply = $null
    if ($null -ne $env:ADR_STD_ANSWER) { $reply = $env:ADR_STD_ANSWER }
    elseif ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) { $reply = Read-Host "Posso acrescentá-la ao PATH do seu usuário? [s/N]" }
    if ($reply -match '^(s|S|sim|Sim|y|Y)$') {
        $new = if ($userPath) { "$userPath;$BinDir" } else { $BinDir }
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        Save-PathEntry $BinDir
        Write-Host '  ✔ pasta acrescentada ao PATH do usuário (abra um novo terminal para valer)'
    } else {
        Write-Host '  Sem problema. Para usar depois, acrescente esta pasta ao PATH do seu usuário:'
        Write-Host "    $BinDir"
    }
}

# --- instala a skill nos agentes ----------------------------------------------

if ($installed -and (Test-Path $tmp)) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp }
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $BinDir 'adr-std.ps1') install @passArgs
exit $LASTEXITCODE
