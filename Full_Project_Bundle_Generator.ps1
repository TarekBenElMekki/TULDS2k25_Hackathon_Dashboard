param(
    [string]$ProjectRoot = ".",
    [string]$ExportFolderName = ".project-export"
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Test-IsExcludedPath {
    param(
        [string]$FullPath,
        [string[]]$ExcludedDirNames
    )

    $segments = $FullPath -split '[\\/]'
    foreach ($dir in $ExcludedDirNames) {
        if ($segments -contains $dir) {
            return $true
        }
    }

    return $false
}

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Resolve-Path $ProjectRoot).Path
$exportRoot = Join-Path $root $ExportFolderName

$structureFile = Join-Path $exportRoot "PROJECT_STRUCTURE.txt"
$codebaseFile  = Join-Path $exportRoot "FULL_CODEBASE_EXPORT.txt"
$contextFile   = Join-Path $exportRoot "CONTEXT_TRANSFER.txt"

Write-Info "Project root: $root"
Write-Info "Export folder: $exportRoot"

$excludedDirNames = @(
    "node_modules",
    ".git",
    ".next",
    "dist",
    "build",
    "coverage",
    ".turbo",
    ".vercel",
    ".idea",
    ".vscode",
    "bin",
    "obj"
)

$excludedExtensions = @(
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".ico", ".svg",
    ".mp4", ".mov", ".avi", ".mkv", ".mp3", ".wav",
    ".zip", ".rar", ".7z", ".tar", ".gz",
    ".pdf", ".doc", ".docx", ".ppt", ".pptx", ".xls", ".xlsx",
    ".lock", ".ttf", ".otf", ".woff", ".woff2",
    ".exe", ".dll", ".so", ".dylib", ".class"
)

Ensure-Dir $exportRoot

try {
    (Get-Item -LiteralPath $exportRoot).Attributes = `
        ((Get-Item -LiteralPath $exportRoot).Attributes -bor [System.IO.FileAttributes]::Hidden)
    Write-Ok "Marked export folder as hidden"
}
catch {
    Write-Warn "Could not mark folder as hidden: $($_.Exception.Message)"
}

$allItems = Get-ChildItem -LiteralPath $root -Recurse -Force | Where-Object {
    $_.FullName -ne $exportRoot -and
    -not (Test-IsExcludedPath -FullPath $_.FullName -ExcludedDirNames ($excludedDirNames + $ExportFolderName.TrimStart(".")))
}

$allFiles = $allItems | Where-Object {
    -not $_.PSIsContainer -and
    ($excludedExtensions -notcontains $_.Extension.ToLowerInvariant()) -and
    $_.FullName -ne $structureFile -and
    $_.FullName -ne $codebaseFile -and
    $_.FullName -ne $contextFile
} | Sort-Object FullName

$allDirs = $allItems | Where-Object { $_.PSIsContainer } | Sort-Object FullName

Write-Info "Directories selected: $($allDirs.Count)"
Write-Info "Files selected: $($allFiles.Count)"

# ------------------------------------------------------------
# 1) PROJECT_STRUCTURE.txt
# ------------------------------------------------------------

$structureSb = New-Object System.Text.StringBuilder
[void]$structureSb.AppendLine("=========================================")
[void]$structureSb.AppendLine("PROJECT STRUCTURE")
[void]$structureSb.AppendLine("=========================================")
[void]$structureSb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$structureSb.AppendLine("Project root: $root")
[void]$structureSb.AppendLine("")

[void]$structureSb.AppendLine("[DIRECTORIES]")
foreach ($dir in $allDirs) {
    $relative = $dir.FullName.Substring($root.Length).TrimStart('\','/')
    [void]$structureSb.AppendLine($relative)
}

[void]$structureSb.AppendLine("")
[void]$structureSb.AppendLine("[FILES]")
foreach ($file in $allFiles) {
    $relative = $file.FullName.Substring($root.Length).TrimStart('\','/')
    [void]$structureSb.AppendLine($relative)
}

Write-Utf8NoBomFile -Path $structureFile -Content $structureSb.ToString()
Write-Ok "Wrote PROJECT_STRUCTURE.txt"

# ------------------------------------------------------------
# 2) FULL_CODEBASE_EXPORT.txt
# ------------------------------------------------------------

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$writer = New-Object System.IO.StreamWriter($codebaseFile, $false, $utf8NoBom)

try {
    $writer.WriteLine("=========================================")
    $writer.WriteLine("FULL CODEBASE EXPORT")
    $writer.WriteLine("=========================================")
    $writer.WriteLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $writer.WriteLine("Project root: $root")
    $writer.WriteLine("Files included: $($allFiles.Count)")
    $writer.WriteLine("")

    foreach ($file in $allFiles) {
        $relative = $file.FullName.Substring($root.Length).TrimStart('\','/')

        $writer.WriteLine("=========================================")
        $writer.WriteLine("FILE: $($file.FullName)")
        $writer.WriteLine("RELATIVE: $relative")
        $writer.WriteLine("SIZE: $($file.Length) bytes")
        $writer.WriteLine("LAST WRITE: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))")
        $writer.WriteLine("=========================================")

        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            $writer.WriteLine($content)
        }
        catch {
            $writer.WriteLine("[ERROR READING FILE]")
            $writer.WriteLine($_.Exception.Message)
        }

        $writer.WriteLine("")
        $writer.WriteLine("")
    }

    $writer.Flush()
}
finally {
    $writer.Dispose()
}

Write-Ok "Wrote FULL_CODEBASE_EXPORT.txt"

# ------------------------------------------------------------
# 3) CONTEXT_TRANSFER.txt
# ------------------------------------------------------------

$fileCount = $allFiles.Count
$dirCount = $allDirs.Count

$topLevelDirs = Get-ChildItem -LiteralPath $root -Directory -Force | Where-Object {
    $_.Name -notin $excludedDirNames -and $_.Name -ne $ExportFolderName.TrimStart(".")
} | Sort-Object Name | Select-Object -ExpandProperty Name

$topLevelFiles = Get-ChildItem -LiteralPath $root -File -Force | Where-Object {
    ($excludedExtensions -notcontains $_.Extension.ToLowerInvariant()) -and
    $_.Name -ne (Split-Path $structureFile -Leaf) -and
    $_.Name -ne (Split-Path $codebaseFile -Leaf) -and
    $_.Name -ne (Split-Path $contextFile -Leaf)
} | Sort-Object Name | Select-Object -ExpandProperty Name

$contextSb = New-Object System.Text.StringBuilder
[void]$contextSb.AppendLine("=========================================")
[void]$contextSb.AppendLine("CONTEXT TRANSFER")
[void]$contextSb.AppendLine("=========================================")
[void]$contextSb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$contextSb.AppendLine("Project root: $root")
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("Use this bundle to continue work in another conversation or environment.")
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("SUMMARY")
[void]$contextSb.AppendLine("- Total directories exported: $dirCount")
[void]$contextSb.AppendLine("- Total files exported: $fileCount")
[void]$contextSb.AppendLine("- Hidden export folder: $ExportFolderName")
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("TOP-LEVEL DIRECTORIES")
foreach ($dirName in $topLevelDirs) {
    [void]$contextSb.AppendLine("- $dirName")
}
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("TOP-LEVEL FILES")
foreach ($fileName in $topLevelFiles) {
    [void]$contextSb.AppendLine("- $fileName")
}
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("BUNDLE CONTENTS")
[void]$contextSb.AppendLine("- PROJECT_STRUCTURE.txt -> directory and file map")
[void]$contextSb.AppendLine("- FULL_CODEBASE_EXPORT.txt -> full readable export of included files")
[void]$contextSb.AppendLine("- CONTEXT_TRANSFER.txt -> this summary and handoff note")
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("SUGGESTED HANDOFF PROMPT")
[void]$contextSb.AppendLine("I am continuing work on this project. Please use the exported bundle in $ExportFolderName. Start by reading CONTEXT_TRANSFER.txt, then PROJECT_STRUCTURE.txt, then inspect FULL_CODEBASE_EXPORT.txt for implementation details. Help me continue from the current codebase without re-architecting unless needed.")
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("EXCLUSIONS")
[void]$contextSb.AppendLine("- Common generated/build folders were excluded")
[void]$contextSb.AppendLine("- Binary/media/document/font/archive files were excluded")
[void]$contextSb.AppendLine("- The export folder itself was excluded from re-export")
[void]$contextSb.AppendLine("")
[void]$contextSb.AppendLine("NOTES")
[void]$contextSb.AppendLine("- This export is intended for code review, migration, and context transfer.")
[void]$contextSb.AppendLine("- If you need binary assets too, use a separate archive/export flow.")

Write-Utf8NoBomFile -Path $contextFile -Content $contextSb.ToString()
Write-Ok "Wrote CONTEXT_TRANSFER.txt"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Project export bundle complete." -ForegroundColor Green
Write-Host "Hidden folder: $exportRoot" -ForegroundColor Green
Write-Host "Files created:" -ForegroundColor Green
Write-Host "  - $structureFile" -ForegroundColor Green
Write-Host "  - $codebaseFile" -ForegroundColor Green
Write-Host "  - $contextFile" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan



