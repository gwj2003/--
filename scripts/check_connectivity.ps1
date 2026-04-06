$ErrorActionPreference = 'Stop'

function Add-Result {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Name,
        [string]$Status,
        [string]$Detail
    )
    $List.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
    }) | Out-Null
}

function Load-EnvFile {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path $Path)) {
        return $map
    }

    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) {
            return
        }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) {
            return
        }
        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $map[$key] = $value
    }

    return $map
}

function Get-EnvValue {
    param(
        [hashtable]$EnvMap,
        [string]$Key,
        [string]$Default = ''
    )

    if ($EnvMap.ContainsKey($Key) -and $EnvMap[$Key]) {
        return [string]$EnvMap[$Key]
    }
    return $Default
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

$envCandidates = @(
    (Join-Path $projectRoot 'backend\.env'),
    (Join-Path $projectRoot '.env')
)

$envPath = $null
foreach ($candidate in $envCandidates) {
    if (Test-Path $candidate) {
        $envPath = $candidate
        break
    }
}

$results = New-Object 'System.Collections.Generic.List[object]'

if (-not $envPath) {
    Add-Result -List $results -Name 'Env file' -Status 'FAIL' -Detail 'No .env found in backend/.env or ./.env'
    $envMap = @{}
} else {
    Add-Result -List $results -Name 'Env file' -Status 'PASS' -Detail "Using $envPath"
    $envMap = Load-EnvFile -Path $envPath
}

$neo4jUri = Get-EnvValue -EnvMap $envMap -Key 'NEO4J_URI' -Default 'bolt://localhost:7687'
$neo4jUser = Get-EnvValue -EnvMap $envMap -Key 'NEO4J_USERNAME' -Default 'neo4j'
$neo4jPass = Get-EnvValue -EnvMap $envMap -Key 'NEO4J_PASSWORD' -Default ''
$neo4jDb = Get-EnvValue -EnvMap $envMap -Key 'NEO4J_DATABASE' -Default 'neo4j'

$apiBase = Get-EnvValue -EnvMap $envMap -Key 'OPENAI_API_BASE' -Default 'https://api.deepseek.com'
$apiKey = Get-EnvValue -EnvMap $envMap -Key 'OPENAI_API_KEY' -Default ''

if ($apiKey) {
    Add-Result -List $results -Name 'LLM key present' -Status 'PASS' -Detail ("OPENAI_API_KEY length=" + $apiKey.Length)
} else {
    Add-Result -List $results -Name 'LLM key present' -Status 'FAIL' -Detail 'OPENAI_API_KEY is empty'
}

if ($neo4jPass) {
    Add-Result -List $results -Name 'Neo4j password present' -Status 'PASS' -Detail ("NEO4J_PASSWORD length=" + $neo4jPass.Length)
} else {
    Add-Result -List $results -Name 'Neo4j password present' -Status 'FAIL' -Detail 'NEO4J_PASSWORD is empty'
}

$neo4jHost = 'localhost'
$neo4jBoltPort = 7687

try {
    $uri = [System.Uri]$neo4jUri
    if ($uri.Host) {
        $neo4jHost = $uri.Host
    }
    if ($uri.Port -gt 0) {
        $neo4jBoltPort = $uri.Port
    }
} catch {
    Add-Result -List $results -Name 'Neo4j URI parse' -Status 'WARN' -Detail "Could not parse NEO4J_URI: $neo4jUri"
}

$neo4jHttpPort = 7474
$neo4jHttpUrl = "http://$neo4jHost`:$neo4jHttpPort/db/$neo4jDb/tx/commit"

try {
    $tcp = Test-NetConnection -ComputerName $neo4jHost -Port $neo4jBoltPort -WarningAction SilentlyContinue
    if ($tcp.TcpTestSucceeded) {
        Add-Result -List $results -Name 'Neo4j TCP port' -Status 'PASS' -Detail ("{0}:{1} reachable" -f $neo4jHost, $neo4jBoltPort)
    } else {
        Add-Result -List $results -Name 'Neo4j TCP port' -Status 'FAIL' -Detail ("{0}:{1} not reachable" -f $neo4jHost, $neo4jBoltPort)
    }
} catch {
    Add-Result -List $results -Name 'Neo4j TCP port' -Status 'WARN' -Detail $_.Exception.Message
}

if ($neo4jUser -and $neo4jPass) {
    try {
        $pair = "$neo4jUser`:$neo4jPass"
        $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
        $headers = @{ Authorization = "Basic $b64"; 'Content-Type' = 'application/json' }
        $body = '{"statements":[{"statement":"RETURN 1 AS ok"}]}'
        $resp = Invoke-RestMethod -Method Post -Uri $neo4jHttpUrl -Headers $headers -Body $body -TimeoutSec 10

        if ($resp.errors -and $resp.errors.Count -gt 0) {
            $err = $resp.errors[0].message
            Add-Result -List $results -Name 'Neo4j auth/query' -Status 'FAIL' -Detail $err
        } else {
            Add-Result -List $results -Name 'Neo4j auth/query' -Status 'PASS' -Detail "Auth OK on $neo4jHttpUrl"
        }
    } catch {
        Add-Result -List $results -Name 'Neo4j auth/query' -Status 'FAIL' -Detail $_.Exception.Message
    }
} else {
    Add-Result -List $results -Name 'Neo4j auth/query' -Status 'FAIL' -Detail 'Missing Neo4j username or password'
}

$modelsUrl = ($apiBase.TrimEnd('/') + '/v1/models')
try {
    $headers = @{ Authorization = "Bearer $apiKey" }
    $resp = Invoke-RestMethod -Method Get -Uri $modelsUrl -Headers $headers -TimeoutSec 15
    if ($resp -and $resp.data) {
        $count = @($resp.data).Count
        Add-Result -List $results -Name 'LLM API /v1/models' -Status 'PASS' -Detail "Reachable, models count=$count"
    } else {
        Add-Result -List $results -Name 'LLM API /v1/models' -Status 'WARN' -Detail 'Reachable but response has no model list'
    }
} catch {
    $msg = $_.Exception.Message
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
        $code = [int]$_.Exception.Response.StatusCode
        if ($code -eq 401 -or $code -eq 403) {
            Add-Result -List $results -Name 'LLM API /v1/models' -Status 'FAIL' -Detail "Auth failed (HTTP $code)"
        } else {
            Add-Result -List $results -Name 'LLM API /v1/models' -Status 'FAIL' -Detail "HTTP $code"
        }
    } else {
        Add-Result -List $results -Name 'LLM API /v1/models' -Status 'FAIL' -Detail $msg
    }
}

$passCount = @($results | Where-Object { $_.Status -eq 'PASS' }).Count
$warnCount = @($results | Where-Object { $_.Status -eq 'WARN' }).Count
$failCount = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count

Write-Host ''
Write-Host '================ Connectivity Checklist ================'
$results | ForEach-Object {
    Write-Host ("[{0}] {1} - {2}" -f $_.Status, $_.Name, $_.Detail)
}
Write-Host '--------------------------------------------------------'
Write-Host ("PASS={0} WARN={1} FAIL={2}" -f $passCount, $warnCount, $failCount)

if ($failCount -gt 0) {
    exit 1
}
exit 0
