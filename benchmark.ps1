param(
    [string]$Integrante = "equipo",
    [switch]$Quick
)

$ErrorActionPreference = "Stop"

function ConvertTo-SafeFolderName {
    param([string]$Name)

    $safe = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = "equipo"
    }

    $safe = $safe -replace '[<>:"/\\|?*]', '_'
    $safe = $safe -replace '\s+', '_'
    $safe = $safe -replace '[^\p{L}\p{Nd}_.-]', '_'
    $safe = $safe.Trim(' ', '.', '_')

    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "equipo"
    }

    return $safe
}

function Get-StdDevSample {
    param([double[]]$Values)

    if ($Values.Count -le 1) {
        return 0.0
    }

    $avg = ($Values | Measure-Object -Average).Average
    $sum = 0.0
    foreach ($value in $Values) {
        $sum += [math]::Pow($value - $avg, 2)
    }

    return [math]::Sqrt($sum / ($Values.Count - 1))
}

function Get-Median {
    param([double[]]$Values)

    $sorted = @($Values | Sort-Object)
    $count = $sorted.Count
    if ($count -eq 0) {
        return $null
    }

    $middle = [int][math]::Floor($count / 2)
    if ($count % 2 -eq 1) {
        return [double]$sorted[$middle]
    }

    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function Invoke-BenchmarkProgram {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    $output = & $Executable @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()

    if ($exitCode -ne 0) {
        throw "Fallo $Executable $($Arguments -join ' ') con codigo $exitCode`n$text"
    }

    if ($text -notmatch 'Tiempo:\s*([0-9]+(?:[.,][0-9]+)?)\s*s') {
        throw "No se pudo leer Tiempo desde la salida de $Executable $($Arguments -join ' ')`n$text"
    }
    $timeText = $Matches[1] -replace ',', '.'
    $time = [double]::Parse($timeText, [System.Globalization.CultureInfo]::InvariantCulture)

    if ($text -notmatch 'Checksum:\s*(\d+)') {
        throw "No se pudo leer Checksum desde la salida de $Executable $($Arguments -join ' ')`n$text"
    }
    $checksum = $Matches[1]

    $threads = $null
    if ($text -match 'Hilos:\s*(\d+)') {
        $threads = [int]$Matches[1]
    }

    $size = $null
    if ($text -match 'Tamano:\s*(\d+)\s*x\s*(\d+)') {
        $size = "$($Matches[1])x$($Matches[2])"
    } elseif ($text -match 'Imagen:\s*(\d+)\s*x\s*(\d+)') {
        $size = "$($Matches[1])x$($Matches[2])"
    }

    return [pscustomobject]@{
        Tiempo = $time
        Checksum = $checksum
        Hilos = $threads
        Tamano = $size
        Salida = $text
    }
}

function Test-ExecutableExists {
    param([string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "No se encontro el ejecutable requerido: $Path"
    }
}

function Add-RawResult {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$Problem,
        [string]$Size,
        [string]$Mode,
        [int]$Threads,
        [object]$Block,
        [int]$Repetition,
        [double]$TimeSeconds,
        [string]$Checksum
    )

    $Rows.Add([pscustomobject]@{
        problema = $Problem
        tamano = $Size
        modo = $Mode
        hilos = $Threads
        bloque = if ($null -ne $Block -and $Block -ne "") { [int]$Block } else { "" }
        repeticion = $Repetition
        tiempo_segundos = $TimeSeconds.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        checksum = $Checksum
    })
}

function Get-ConfigurationSummary {
    param(
        [object[]]$Rows,
        [string]$Problem,
        [string]$Size,
        [string]$Mode,
        [int]$Threads,
        [string]$Block,
        [double]$SequentialAverage
    )

    $times = @($Rows | ForEach-Object {
        [double]::Parse($_.tiempo_segundos, [System.Globalization.CultureInfo]::InvariantCulture)
    })

    $avg = ($times | Measure-Object -Average).Average
    $min = ($times | Measure-Object -Minimum).Minimum
    $max = ($times | Measure-Object -Maximum).Maximum
    $median = Get-Median -Values $times
    $stddev = Get-StdDevSample -Values $times

    $speedup = if ($Mode -eq "paralelo") { $SequentialAverage / $avg } else { 1.0 }
    $efficiency = if ($Mode -eq "paralelo") { $speedup / $Threads } else { 1.0 }

    return [pscustomobject]@{
        problema = $Problem
        tamano = $Size
        modo = $Mode
        hilos = $Threads
        bloque = $Block
        corridas = $Rows.Count
        tiempo_promedio = $avg.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        mediana = $median.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        tiempo_minimo = $min.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        tiempo_maximo = $max.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        desviacion_estandar = $stddev.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        speedup = $speedup.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        eficiencia = $efficiency.ToString("0.000000", [System.Globalization.CultureInfo]::InvariantCulture)
        eficiencia_porcentaje = ($efficiency * 100.0).ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)
    }
}

function Get-SystemInfo {
    $processor = ""
    $physicalCores = ""
    $logicalProcessors = ""
    $os = ""
    $gccVersion = ""

    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $processor = $cpu.Name
        $physicalCores = $cpu.NumberOfCores
        $logicalProcessors = $cpu.NumberOfLogicalProcessors
    } catch {
        $physicalCores = "No disponible"
    }

    if ([string]::IsNullOrWhiteSpace($processor)) {
        try {
            $computerInfo = Get-ComputerInfo
            $processor = $computerInfo.CsProcessors.Name | Select-Object -First 1
        } catch {
        }
    }

    if ([string]::IsNullOrWhiteSpace($processor) -and $env:PROCESSOR_IDENTIFIER) {
        $processor = $env:PROCESSOR_IDENTIFIER
    }

    if ([string]::IsNullOrWhiteSpace($processor)) {
        $processor = "No disponible"
    }

    if ([string]::IsNullOrWhiteSpace($physicalCores)) {
        $physicalCores = "No disponible"
    }

    if ([string]::IsNullOrWhiteSpace($logicalProcessors)) {
        $logicalProcessors = [Environment]::ProcessorCount
    }

    if ([string]::IsNullOrWhiteSpace($logicalProcessors) -and $env:NUMBER_OF_PROCESSORS) {
        $logicalProcessors = $env:NUMBER_OF_PROCESSORS
    }

    if ([string]::IsNullOrWhiteSpace($logicalProcessors)) {
        $logicalProcessors = "No disponible"
    }

    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $os = "$($osInfo.Caption) $($osInfo.Version)"
    } catch {
    }

    if ([string]::IsNullOrWhiteSpace($os)) {
        try {
            $computerInfo = Get-ComputerInfo
            $os = "$($computerInfo.WindowsProductName) $($computerInfo.WindowsVersion)"
        } catch {
        }
    }

    if ([string]::IsNullOrWhiteSpace($os)) {
        $os = [System.Environment]::OSVersion.VersionString
    }

    if ([string]::IsNullOrWhiteSpace($os)) {
        $os = "No disponible"
    }

    try {
        $gccOutput = & gcc --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $gccOutput.Count -gt 0) {
            $gccVersion = $gccOutput[0]
        }
    } catch {
        $gccVersion = "No disponible"
    }

    return [pscustomobject]@{
        Processor = $processor
        PhysicalCores = $physicalCores
        LogicalProcessors = $logicalProcessors
        OS = $os
        GccVersion = $gccVersion
    }
}

function Invoke-Configuration {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$Problem,
        [string]$SizeLabel,
        [string]$Mode,
        [string]$Executable,
        [string[]]$Arguments,
        [int]$Threads,
        [object]$Block,
        [int]$Repetitions,
        [string]$ExpectedChecksum
    )

    for ($rep = 1; $rep -le $Repetitions; $rep++) {
        $result = Invoke-BenchmarkProgram -Executable $Executable -Arguments $Arguments
        Write-Host ("Corrida {0}/{1}: {2:0.000000} s" -f $rep, $Repetitions, $result.Tiempo)

        if ($ExpectedChecksum -and $result.Checksum -ne $ExpectedChecksum) {
            Write-Host "ERROR: checksum distinto" -ForegroundColor Red
            Write-Host "Problema: $Problem"
            Write-Host "Tamano: $SizeLabel"
            Write-Host "Modo: $Mode"
            Write-Host "Hilos: $Threads"
            Write-Host "Corrida: $rep"
            Write-Host "Esperado: $ExpectedChecksum"
            Write-Host "Obtenido: $($result.Checksum)"
            throw "Checksum invalido para $Problem $SizeLabel $Mode hilos=$Threads corrida=$rep"
        }

        Add-RawResult `
            -Rows $Rows `
            -Problem $Problem `
            -Size $SizeLabel `
            -Mode $Mode `
            -Threads $Threads `
            -Block $Block `
            -Repetition $rep `
            -TimeSeconds $result.Tiempo `
            -Checksum $result.Checksum
    }
}

function New-MarkdownSummary {
    param(
        [object[]]$SummaryRows,
        [object]$SystemInfo,
        [string]$Integrator,
        [datetime]$StartedAt
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Resumen de Benchmark")
    $lines.Add("")
    $lines.Add("## Informacion del equipo")
    $lines.Add("")
    $lines.Add("- Integrante: $Integrator")
    $lines.Add("- Fecha/hora: $($StartedAt.ToString('yyyy-MM-dd HH:mm:ss'))")
    $lines.Add("- Procesador: $($SystemInfo.Processor)")
    $lines.Add("- Nucleos fisicos: $($SystemInfo.PhysicalCores)")
    $lines.Add("- Procesadores logicos: $($SystemInfo.LogicalProcessors)")
    $lines.Add("- GCC: $($SystemInfo.GccVersion)")
    $lines.Add("- Sistema operativo: $($SystemInfo.OS)")
    $lines.Add("")

    foreach ($problem in @("matrices", "blur")) {
        $title = if ($problem -eq "matrices") { "Matrices" } else { "Blur" }
        $lines.Add("## $title")
        $lines.Add("")
        $lines.Add("| Tamano | Hilos | Tiempo secuencial (s) | Tiempo promedio (s) | Speedup | Eficiencia % |")
        $lines.Add("|---|---:|---:|---:|---:|---:|")

        $problemRows = @($SummaryRows | Where-Object { $_.problema -eq $problem } | Sort-Object tamano, hilos, modo)
        foreach ($row in $problemRows) {
            if ($row.modo -ne "paralelo") {
                continue
            }

            $seq = $SummaryRows | Where-Object {
                $_.problema -eq $row.problema -and $_.tamano -eq $row.tamano -and $_.modo -eq "secuencial"
            } | Select-Object -First 1

            $lines.Add("| $($row.tamano) | $($row.hilos) | $($seq.tiempo_promedio) | $($row.tiempo_promedio) | $($row.speedup) | $($row.eficiencia_porcentaje) |")
        }

        $lines.Add("")
    }

    return $lines
}

$root = Split-Path -Parent $PSCommandPath
Set-Location $root

$msysPath = "C:\msys64\ucrt64\bin"
if (Test-Path $msysPath) {
    $env:PATH = "$msysPath;$env:PATH"
}

$executables = @{
    matricesSecuencial = Join-Path $root "matrices_secuencial.exe"
    matricesParalelo = Join-Path $root "matrices_paralelo.exe"
    blurSecuencial = Join-Path $root "blur_secuencial.exe"
    blurParalelo = Join-Path $root "blur_paralelo.exe"
}

foreach ($exe in $executables.Values) {
    Test-ExecutableExists -Path $exe
}

$repetitions = 5
$matrixSizes = @(1024, 1536, 2048)
$blurSizes = @(
    @{ Width = 3840; Height = 2160 },
    @{ Width = 7680; Height = 4320 }
)

if ($Quick) {
    $repetitions = 2
    $matrixSizes = @(512)
    $blurSizes = @(@{ Width = 1920; Height = 1080 })
}

$threadsList = @(1, 2, 4, 8)
$blockSize = 32
$safeIntegrator = ConvertTo-SafeFolderName -Name $Integrante
$outputDir = Join-Path $root "docs\resultados\$safeIntegrator"
$rawPath = Join-Path $outputDir "benchmark_raw.csv"
$summaryPath = Join-Path $outputDir "benchmark_summary.csv"
$markdownPath = Join-Path $outputDir "benchmark_summary.md"
$startedAt = Get-Date
$systemInfo = Get-SystemInfo

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$rawRows = [System.Collections.Generic.List[object]]::new()
$errors = [System.Collections.Generic.List[string]]::new()

foreach ($n in $matrixSizes) {
    $sizeLabel = "${n}x${n}"
    Write-Host ""
    Write-Host "========================================"
    Write-Host "MATRICES $n x $n"
    Write-Host "========================================"

    try {
        Write-Host ""
        Write-Host "Calentamiento secuencial"
        [void](Invoke-BenchmarkProgram -Executable $executables.matricesSecuencial -Arguments @([string]$n))

        Write-Host ""
        Write-Host "Secuencial"
        Invoke-Configuration `
            -Rows $rawRows `
            -Problem "matrices" `
            -SizeLabel $sizeLabel `
            -Mode "secuencial" `
            -Executable $executables.matricesSecuencial `
            -Arguments @([string]$n) `
            -Threads 1 `
            -Block $null `
            -Repetitions $repetitions `
            -ExpectedChecksum $null

        $referenceChecksum = ($rawRows | Where-Object {
            $_.problema -eq "matrices" -and $_.tamano -eq $sizeLabel -and $_.modo -eq "secuencial"
        } | Select-Object -First 1).checksum

        foreach ($threads in $threadsList) {
            Write-Host ""
            Write-Host "Calentamiento OpenMP - $threads hilo$(if ($threads -eq 1) { '' } else { 's' })"
            $warmup = Invoke-BenchmarkProgram -Executable $executables.matricesParalelo -Arguments @([string]$n, [string]$threads, [string]$blockSize)
            if ($warmup.Checksum -ne $referenceChecksum) {
                throw "ERROR: checksum distinto en calentamiento matrices $sizeLabel hilos=$threads. Esperado=$referenceChecksum Obtenido=$($warmup.Checksum)"
            }

            Write-Host ""
            Write-Host "OpenMP - $threads hilo$(if ($threads -eq 1) { '' } else { 's' })"
            Invoke-Configuration `
                -Rows $rawRows `
                -Problem "matrices" `
                -SizeLabel $sizeLabel `
                -Mode "paralelo" `
                -Executable $executables.matricesParalelo `
                -Arguments @([string]$n, [string]$threads, [string]$blockSize) `
                -Threads $threads `
                -Block $blockSize `
                -Repetitions $repetitions `
                -ExpectedChecksum $referenceChecksum
        }

        Write-Host ""
        Write-Host "Checksum: OK" -ForegroundColor Green
    } catch {
        $message = $_.Exception.Message
        $errors.Add("matrices ${sizeLabel}: $message")
        Write-Host "ERROR: $message" -ForegroundColor Red
    }
}

foreach ($size in $blurSizes) {
    $width = [int]$size.Width
    $height = [int]$size.Height
    $sizeLabel = "${width}x${height}"
    Write-Host ""
    Write-Host "========================================"
    Write-Host "BLUR $width x $height"
    Write-Host "========================================"

    try {
        Write-Host ""
        Write-Host "Calentamiento secuencial"
        [void](Invoke-BenchmarkProgram -Executable $executables.blurSecuencial -Arguments @([string]$width, [string]$height))

        Write-Host ""
        Write-Host "Secuencial"
        Invoke-Configuration `
            -Rows $rawRows `
            -Problem "blur" `
            -SizeLabel $sizeLabel `
            -Mode "secuencial" `
            -Executable $executables.blurSecuencial `
            -Arguments @([string]$width, [string]$height) `
            -Threads 1 `
            -Block $null `
            -Repetitions $repetitions `
            -ExpectedChecksum $null

        $referenceChecksum = ($rawRows | Where-Object {
            $_.problema -eq "blur" -and $_.tamano -eq $sizeLabel -and $_.modo -eq "secuencial"
        } | Select-Object -First 1).checksum

        foreach ($threads in $threadsList) {
            Write-Host ""
            Write-Host "Calentamiento OpenMP - $threads hilo$(if ($threads -eq 1) { '' } else { 's' })"
            $warmup = Invoke-BenchmarkProgram -Executable $executables.blurParalelo -Arguments @([string]$width, [string]$height, [string]$threads)
            if ($warmup.Checksum -ne $referenceChecksum) {
                throw "ERROR: checksum distinto en calentamiento blur $sizeLabel hilos=$threads. Esperado=$referenceChecksum Obtenido=$($warmup.Checksum)"
            }

            Write-Host ""
            Write-Host "OpenMP - $threads hilo$(if ($threads -eq 1) { '' } else { 's' })"
            Invoke-Configuration `
                -Rows $rawRows `
                -Problem "blur" `
                -SizeLabel $sizeLabel `
                -Mode "paralelo" `
                -Executable $executables.blurParalelo `
                -Arguments @([string]$width, [string]$height, [string]$threads) `
                -Threads $threads `
                -Block $null `
                -Repetitions $repetitions `
                -ExpectedChecksum $referenceChecksum
        }

        Write-Host ""
        Write-Host "Checksum: OK" -ForegroundColor Green
    } catch {
        $message = $_.Exception.Message
        $errors.Add("blur ${sizeLabel}: $message")
        Write-Host "ERROR: $message" -ForegroundColor Red
    }
}

$rawRows | Export-Csv -Path $rawPath -NoTypeInformation -Encoding UTF8

$summaryRows = [System.Collections.Generic.List[object]]::new()
$groups = $rawRows | Group-Object problema, tamano, modo, hilos, bloque

foreach ($group in $groups) {
    $rows = @($group.Group)
    $first = $rows[0]
    $sequentialRows = @($rawRows | Where-Object {
        $_.problema -eq $first.problema -and $_.tamano -eq $first.tamano -and $_.modo -eq "secuencial"
    })

    if ($sequentialRows.Count -eq 0) {
        continue
    }

    $seqTimes = @($sequentialRows | ForEach-Object {
        [double]::Parse($_.tiempo_segundos, [System.Globalization.CultureInfo]::InvariantCulture)
    })
    $seqAvg = ($seqTimes | Measure-Object -Average).Average

    $summaryRows.Add((Get-ConfigurationSummary `
        -Rows $rows `
        -Problem $first.problema `
        -Size $first.tamano `
        -Mode $first.modo `
        -Threads ([int]$first.hilos) `
        -Block ([string]$first.bloque) `
        -SequentialAverage $seqAvg))
}

$summaryRows |
    Sort-Object problema, tamano, modo, hilos |
    Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8

$markdownLines = New-MarkdownSummary `
    -SummaryRows $summaryRows `
    -SystemInfo $systemInfo `
    -Integrator $Integrante `
    -StartedAt $startedAt

$markdownLines | Set-Content -Path $markdownPath -Encoding UTF8

Write-Host ""
Write-Host "========================================"
Write-Host "RESULTADOS"
Write-Host "========================================"
Write-Host "CSV crudo: $rawPath"
Write-Host "CSV resumen: $summaryPath"
Write-Host "Markdown: $markdownPath"

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "ERRORES" -ForegroundColor Red
    foreach ($errorMessage in $errors) {
        Write-Host "- $errorMessage"
    }
    exit 1
}
