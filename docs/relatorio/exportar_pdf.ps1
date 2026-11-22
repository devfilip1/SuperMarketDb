# Abre relatorio_tecnico.docx no Word, atualiza o sumario e salva relatorio_tecnico.pdf
# Uso (PowerShell, na pasta do repositorio):  .\docs\relatorio\exportar_pdf.ps1
# Trabalha numa copia em %TEMP%, porque o Word nao abre arquivos em caminhos muito longos.
$origem  = Join-Path $PSScriptRoot 'relatorio_tecnico.docx'
$tmpDir  = Join-Path $env:TEMP 'relatorio_bd2'
New-Item -ItemType Directory -Force $tmpDir | Out-Null
$tmpDocx = Join-Path $tmpDir 'relatorio_tecnico.docx'
$tmpPdf  = Join-Path $tmpDir 'relatorio_tecnico.pdf'
Copy-Item $origem $tmpDocx -Force

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    $doc = $word.Documents.Open($tmpDocx, $false, $false, $false)
    $doc.Fields.Update() | Out-Null
    foreach ($toc in $doc.TablesOfContents) { $toc.Update() }
    $doc.Save()
    $paginas = $doc.ComputeStatistics(2)          # 2 = wdStatisticPages
    $doc.ExportAsFixedFormat([string]$tmpPdf, 17) # 17 = wdExportFormatPDF
    $doc.Close([ref]0)
} finally {
    $word.Quit()
}
Copy-Item $tmpDocx $origem -Force
Copy-Item $tmpPdf (Join-Path $PSScriptRoot 'relatorio_tecnico.pdf') -Force
"PDF gerado: relatorio_tecnico.pdf ($paginas paginas)"
