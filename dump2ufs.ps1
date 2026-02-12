#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a UFS2 filesystem image from a game directory using UFS2Tool.exe

.DESCRIPTION
    This script creates a UFS2 filesystem image from a game directory.
    It automatically detects optimal block/fragment sizes and parses game metadata.

.PARAMETER InputPath
    Path to the game directory (must contain sce_sys/param.json)

.PARAMETER OutputFile
    Output filename for the UFS2 image

.PARAMETER Label
    UFS filesystem label (max 16 chars, default: auto-generated from title info)

.PARAMETER SkipConfirmation
    Skip the confirmation prompt

.PARAMETER UFS2ToolPath
    Path to UFS2Tool.exe (optional, will search script directory and PATH if not provided)

.EXAMPLE
    .\makefs.ps1 -InputPath "C:\Games\PPSA00000-app" -OutputFile "game.ffpkg"

.EXAMPLE
    .\makefs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg" -l "My_Game-00000" -y

.EXAMPLE
    .\makefs.ps1 -i "C:\Games\PPSA00000-app" -o "game.ffpkg" -u "C:\Tools\UFS2Tool.exe"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Input directory path (must contain sce_sys/param.json)")]
    [Alias("i")]
    [string]$InputPath,

    [Parameter(Mandatory=$false, HelpMessage="Output filename for the UFS2 image")]
    [Alias("o")]
    [string]$OutputFile,

    [Parameter(Mandatory=$false, HelpMessage="UFS filesystem label (max 16 chars)")]
    [Alias("l")]
    [string]$Label,

    [Parameter(Mandatory=$false, HelpMessage="Skip confirmation prompt")]
    [Alias("y")]
    [switch]$SkipConfirmation,

    [Parameter(Mandatory=$false, HelpMessage="Path to UFS2Tool.exe")]
    [Alias("u")]
    [string]$UFS2ToolPath
)

# Strict error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Show help if required parameters are missing
if (-not $InputPath -or -not $OutputFile) {
    Write-Host "Usage: dump2ufs.ps1 -i input_path [-l ufs_label] [-u ufs2tool_path] [-y] -o output_filename"
    Write-Host "  -i: Input directory path (required)"
    Write-Host "  -l: UFS filesystem label (max 16 chars, default: auto-generated from title info)"
    Write-Host "  -u: Path to UFS2Tool.exe (optional)"
    Write-Host "  -y: Skip confirmation prompt"
    Write-Host "  -o: Output filename (required)"
    exit 1
}

# Function to validate UFS label
function Test-UfsLabel {
    param([string]$LabelText)
    
    if ($LabelText.Length -gt 16) {
        throw "Error: UFS_LABEL can't exceed 16 chars (provided: '$LabelText')"
    }
    
    if ($LabelText -notmatch '^[A-Za-z0-9._-]+$') {
        throw "Error: UFS_LABEL can only contain letters, numbers, dots, underscores, and hyphens (provided: '$LabelText')"
    }
}

# Function to find UFS2Tool.exe
function Find-UFS2Tool {
    # Check current directory
    $currentDir = Join-Path $PSScriptRoot "UFS2Tool.exe"
    if (Test-Path $currentDir) {
        return $currentDir
    }
    
    # Check if it's in PATH
    $inPath = Get-Command "UFS2Tool.exe" -ErrorAction SilentlyContinue
    if ($inPath) {
        return $inPath.Source
    }
    
    throw "Error: UFS2Tool.exe not found. Please place it in the same directory as this script or add it to your PATH."
}

# Function to parse JSON with fallback for older PowerShell versions
function Get-JsonContent {
    param([string]$Path)
    
    $content = Get-Content -Path $Path -Raw -Encoding UTF8
    return $content | ConvertFrom-Json
}

# Main script
Write-Host "=== dump2ufs for Windows ===" -ForegroundColor Cyan
Write-Host ""

# Validate input path
if (-not (Test-Path -Path $InputPath -PathType Container)) {
    throw "Error: Input path does not exist or is not a directory: $InputPath"
}

$InputPath = (Resolve-Path -Path $InputPath).Path
Write-Host "Input directory: $InputPath" -ForegroundColor Green

# Check for sce_sys/param.json
$paramJsonPath = Join-Path $InputPath "sce_sys\param.json"
if (-not (Test-Path -Path $paramJsonPath -PathType Leaf)) {
    Write-Host "Error: sce_sys\param.json not found in $InputPath" -ForegroundColor Red
    Write-Host "Contents of $InputPath`:" -ForegroundColor Yellow
    Get-ChildItem -Path $InputPath | Format-Table -AutoSize
    throw "Invalid PS5 game directory structure"
}

Write-Host "Found sce_sys\param.json" -ForegroundColor Green

# Find or validate UFS2Tool.exe
if ($UFS2ToolPath) {
    if (-not (Test-Path -Path $UFS2ToolPath -PathType Leaf)) {
        throw "Error: UFS2Tool.exe not found at specified path: $UFS2ToolPath"
    }
    $ufs2ToolPath = $UFS2ToolPath
} else {
    $ufs2ToolPath = Find-UFS2Tool
}
Write-Host "Using UFS2Tool.exe at: $ufs2ToolPath" -ForegroundColor Green

# Validate label if provided
if ($Label) {
    Test-UfsLabel -LabelText $Label
}

# Parse game information from param.json
Write-Host "Parsing game metadata..." -ForegroundColor Cyan
try {
    $paramJson = Get-JsonContent -Path $paramJsonPath
    
    # Parse title ID
    $titleId = $paramJson.titleId
    if (-not $titleId) {
        throw "Error: Failed to parse titleId from param.json"
    }
    
    # Parse title name
    $defaultLang = $paramJson.localizedParameters.defaultLanguage
    if (-not $defaultLang) {
        $defaultLang = "en-US"
    }
    
    $titleName = $paramJson.localizedParameters.$defaultLang.titleName
    if (-not $titleName) {
        throw "Error: Failed to parse titleName from param.json"
    }
    
    Write-Host "Detected game: $titleName (ID: $titleId)" -ForegroundColor Green
} catch {
    Write-Host "Error parsing param.json: $_" -ForegroundColor Red
    throw
}

# Generate label if not provided
if (-not $Label) {
    $titleNameClean = $titleName -replace '[^A-Za-z0-9]', ''
    $titleIdClean = $titleId -replace '[^A-Za-z0-9]', ''
    
    # Take last 5 chars of ID and first 11 chars of name
    $idPart = if ($titleIdClean.Length -gt 5) { $titleIdClean.Substring($titleIdClean.Length - 5) } else { $titleIdClean }
    $namePart = if ($titleNameClean.Length -gt 11) { $titleNameClean.Substring(0, 11) } else { $titleNameClean }
    
    $Label = "$idPart$namePart"
}

Write-Host "UFS Label will be: $Label" -ForegroundColor Green

# Test different block sizes to find optimal configuration
Write-Host ""
Write-Host "Testing block sizes to find optimal configuration..." -ForegroundColor Cyan

$bValues = @(4096, 8192, 16384, 32768, 65536)
$bestSize = $null
$bestB = $null
$bestF = $null

$tempFile = Join-Path $env:TEMP "ufs2tool_test_$(Get-Random).img"

foreach ($b in $bValues) {
    $f = [int]($b / 8)
    
    # Remove temp file if it exists
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
    
    # Set environment variable for UFS2Tool
    $env:__COMPAT_LAYER = "RunAsInvoker"
    
    # Run UFS2Tool to get size estimate
    $args = @(
        "makefs",
        "-b", "0",
        "-o", "bsize=$b,fsize=$f,minfree=0,version=2,optimization=space",
        "-s", "$b",
        $tempFile,
        $InputPath
    )
    
    try {
        $output = & $ufs2ToolPath $args 2>&1 | Out-String
        
        # Extract size from error message
        # UFS2Tool format: "Image size (6 833 565 696 bytes)" with non-breaking spaces (char code 160)
        if ($output -match 'Image size \(([0-9\u00A0 ,.]+) bytes\)') {
            # Remove thousands separators (non-breaking space U+00A0, regular space, comma, period)
            $sizeStr = $matches[1] -replace '[\u00A0 ,.]', ''
            $size = [long]$sizeStr
            
            if ($null -eq $bestSize -or $size -lt $bestSize) {
                $bestSize = $size
                $bestB = $b
                $bestF = $f
            }
            
            Write-Host "  Block size: $b, Fragment size: $f -> Image size: $size bytes" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Warning: Test with block size $b failed: $_" -ForegroundColor Yellow
    }
}

# Clean up temp file
if (Test-Path $tempFile) {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

if ($null -eq $bestSize) {
    throw "Error: Failed to determine optimal block size. Perhaps UFS2Tool.exe changed its output format? Output from last test:`n$output"
}

# Calculate human-readable size
$gbInt = [Math]::Floor($bestSize / 1GB)
$gbFrac = [Math]::Floor((($bestSize % 1GB) * 10) / 1GB)

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Source directory: $InputPath"
Write-Host "Game title: $titleName"
Write-Host "Game ID: $titleId"
Write-Host "UFS Label: $Label"
Write-Host "Optimal block size: $bestB bytes"
Write-Host "Optimal fragment size: $bestF bytes"
Write-Host "Resulting image size: $bestSize bytes (~$gbInt.$gbFrac GB)"
Write-Host "Output file: $OutputFile"
Write-Host ""

# Build command line
$labelParam = if ($Label) { ",label=$Label" } else { "" }
$makefsOptions = "bsize=$bestB,fsize=$bestF,minfree=0,version=2,optimization=space$labelParam"
$makefsArgs = @(
    "makefs",
    "-b", "0",
    "-o", $makefsOptions,
    $OutputFile,
    $InputPath
)

Write-Host "Command to execute:" -ForegroundColor Cyan
Write-Host "UFS2Tool.exe $($makefsArgs -join ' ')" -ForegroundColor White
Write-Host ""

# Confirmation prompt
if (-not $SkipConfirmation) {
    do {
        $response = Read-Host "Please verify the above is correct. Continue? (y/n)"
        $response = $response.Trim().ToLower()
        
        if ($response -eq 'n') {
            Write-Host "Aborted by user." -ForegroundColor Yellow
            exit 1
        }
    } while ($response -ne 'y')
} else {
    Write-Host "Skipping confirmation prompt (-y flag set)" -ForegroundColor Yellow
}

# Create the UFS2 image
Write-Host ""
Write-Host "Creating UFS2 filesystem image..." -ForegroundColor Cyan

# Set environment variable
$env:__COMPAT_LAYER = "RunAsInvoker"

try {
    & $ufs2ToolPath $makefsArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Success! UFS2 image created: $OutputFile" -ForegroundColor Green
        
        if (Test-Path $OutputFile) {
            $fileInfo = Get-Item $OutputFile
            $fileSizeBytes = $fileInfo.Length
            $fileSizeGbInt = [Math]::Floor($fileSizeBytes / 1GB)
            $fileSizeGbFrac = [Math]::Floor((($fileSizeBytes % 1GB) * 10) / 1GB)
            Write-Host "Final file size: $fileSizeBytes bytes (~$fileSizeGbInt.$fileSizeGbFrac GB)" -ForegroundColor Green
        }
    } else {
        throw "UFS2Tool.exe exited with code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error creating UFS2 image: $_" -ForegroundColor Red
    throw
}
