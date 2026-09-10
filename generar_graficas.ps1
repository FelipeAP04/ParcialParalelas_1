param(
    [string]$Integrante = "Vianka_Castro"
)

$ErrorActionPreference = "Stop"
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$root = Split-Path -Parent $PSCommandPath
$resultDir = Join-Path $root "docs\resultados\$Integrante"
$csvPath = Join-Path $resultDir "benchmark_summary.csv"
$chartDir = Join-Path $resultDir "graficas"

if (-not (Test-Path $csvPath -PathType Leaf)) {
    throw "No se encontro el resumen: $csvPath"
}

New-Item -ItemType Directory -Path $chartDir -Force | Out-Null
$data = Import-Csv $csvPath

function Format-Number {
    param([double]$Value, [string]$Pattern = "0.###")
    return $Value.ToString($Pattern, $culture)
}

function Escape-Xml {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function New-LineChart {
    param(
        [string]$Problem,
        [string]$Metric,
        [string]$Title,
        [string]$YAxis,
        [double]$YMax,
        [string]$OutputName
    )

    $width = 960
    $height = 620
    $left = 90
    $right = 720
    $top = 70
    $bottom = 540
    $plotWidth = $right - $left
    $plotHeight = $bottom - $top
    $threads = @(1, 2, 4, 8)
    $colors = @("#2563eb", "#dc2626", "#16a34a", "#9333ea")
    $problemRows = @($data | Where-Object { $_.problema -eq $Problem -and $_.modo -eq "paralelo" })
    $sizes = @($problemRows | Select-Object -ExpandProperty tamano -Unique | Sort-Object)

    function Get-X([int]$ThreadCount) {
        return $left + (($ThreadCount - 1.0) / 7.0) * $plotWidth
    }

    function Get-Y([double]$Value) {
        return $bottom - ($Value / $YMax) * $plotHeight
    }

    $svg = [System.Collections.Generic.List[string]]::new()
    $svg.Add("<svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$width`" height=`"$height`" viewBox=`"0 0 $width $height`">")
    $svg.Add("<rect width=`"100%`" height=`"100%`" fill=`"white`"/>")
    $svg.Add("<text x=`"480`" y=`"34`" text-anchor=`"middle`" font-family=`"Arial`" font-size=`"24`" font-weight=`"700`">$(Escape-Xml $Title)</text>")

    for ($tick = 0; $tick -le 5; $tick++) {
        $value = $YMax * $tick / 5.0
        $y = Get-Y $value
        $yText = Format-Number $y
        $label = Format-Number $value
        $svg.Add("<line x1=`"$left`" y1=`"$yText`" x2=`"$right`" y2=`"$yText`" stroke=`"#e5e7eb`" stroke-width=`"1`"/>")
        $svg.Add("<text x=`"78`" y=`"$(Format-Number ($y + 5))`" text-anchor=`"end`" font-family=`"Arial`" font-size=`"13`" fill=`"#374151`">$label</text>")
    }

    $svg.Add("<line x1=`"$left`" y1=`"$top`" x2=`"$left`" y2=`"$bottom`" stroke=`"#111827`" stroke-width=`"1.5`"/>")
    $svg.Add("<line x1=`"$left`" y1=`"$bottom`" x2=`"$right`" y2=`"$bottom`" stroke=`"#111827`" stroke-width=`"1.5`"/>")

    foreach ($thread in $threads) {
        $x = Get-X $thread
        $xText = Format-Number $x
        $svg.Add("<line x1=`"$xText`" y1=`"$bottom`" x2=`"$xText`" y2=`"546`" stroke=`"#111827`"/>")
        $svg.Add("<text x=`"$xText`" y=`"568`" text-anchor=`"middle`" font-family=`"Arial`" font-size=`"14`">$thread</text>")
    }

    $svg.Add("<text x=`"405`" y=`"596`" text-anchor=`"middle`" font-family=`"Arial`" font-size=`"16`">Numero de hilos</text>")
    $svg.Add("<text transform=`"translate(24 305) rotate(-90)`" text-anchor=`"middle`" font-family=`"Arial`" font-size=`"16`">$(Escape-Xml $YAxis)</text>")

    for ($seriesIndex = 0; $seriesIndex -lt $sizes.Count; $seriesIndex++) {
        $size = $sizes[$seriesIndex]
        $color = $colors[$seriesIndex % $colors.Count]
        $rows = @($problemRows | Where-Object { $_.tamano -eq $size } | Sort-Object { [int]$_.hilos })
        $points = [System.Collections.Generic.List[string]]::new()

        foreach ($row in $rows) {
            $x = Get-X ([int]$row.hilos)
            $value = [double]::Parse($row.$Metric, $culture)
            $y = Get-Y $value
            $points.Add("$(Format-Number $x),$(Format-Number $y)")
        }

        $svg.Add("<polyline points=`"$($points -join ' ')`" fill=`"none`" stroke=`"$color`" stroke-width=`"3`"/>")
        foreach ($row in $rows) {
            $x = Get-X ([int]$row.hilos)
            $value = [double]::Parse($row.$Metric, $culture)
            $y = Get-Y $value
            $svg.Add("<circle cx=`"$(Format-Number $x)`" cy=`"$(Format-Number $y)`" r=`"5`" fill=`"$color`"/>")
        }

        $legendY = 95 + $seriesIndex * 28
        $svg.Add("<line x1=`"760`" y1=`"$legendY`" x2=`"798`" y2=`"$legendY`" stroke=`"$color`" stroke-width=`"3`"/>")
        $svg.Add("<circle cx=`"779`" cy=`"$legendY`" r=`"5`" fill=`"$color`"/>")
        $svg.Add("<text x=`"808`" y=`"$($legendY + 5)`" font-family=`"Arial`" font-size=`"14`">$(Escape-Xml $size)</text>")
    }

    $idealPoints = [System.Collections.Generic.List[string]]::new()
    foreach ($thread in $threads) {
        $idealValue = if ($Metric -eq "speedup") { [double]$thread } else { 100.0 }
        $idealPoints.Add("$(Format-Number (Get-X $thread)),$(Format-Number (Get-Y $idealValue))")
    }
    $svg.Add("<polyline points=`"$($idealPoints -join ' ')`" fill=`"none`" stroke=`"#111827`" stroke-width=`"2.5`" stroke-dasharray=`"8 6`"/>")
    $idealLegendY = 95 + $sizes.Count * 28
    $idealLabel = if ($Metric -eq "speedup") { "Speedup ideal" } else { "Eficiencia ideal (100%)" }
    $svg.Add("<line x1=`"760`" y1=`"$idealLegendY`" x2=`"798`" y2=`"$idealLegendY`" stroke=`"#111827`" stroke-width=`"2.5`" stroke-dasharray=`"8 6`"/>")
    $svg.Add("<text x=`"808`" y=`"$($idealLegendY + 5)`" font-family=`"Arial`" font-size=`"14`">$idealLabel</text>")
    $svg.Add("</svg>")

    $path = Join-Path $chartDir $OutputName
    $svg | Set-Content -Path $path -Encoding UTF8
    Write-Host "Grafica: $path"
}

New-LineChart -Problem "matrices" -Metric "speedup" -Title "Speedup - Multiplicacion de matrices" -YAxis "Speedup" -YMax 9 -OutputName "speedup_matrices.svg"
New-LineChart -Problem "matrices" -Metric "eficiencia_porcentaje" -Title "Eficiencia - Multiplicacion de matrices" -YAxis "Eficiencia (%)" -YMax 125 -OutputName "eficiencia_matrices.svg"
New-LineChart -Problem "blur" -Metric "speedup" -Title "Speedup - Filtro blur" -YAxis "Speedup" -YMax 9 -OutputName "speedup_blur.svg"
New-LineChart -Problem "blur" -Metric "eficiencia_porcentaje" -Title "Eficiencia - Filtro blur" -YAxis "Eficiencia (%)" -YMax 125 -OutputName "eficiencia_blur.svg"
