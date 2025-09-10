#Requires -Version 5.1

<#
.SYNOPSIS
    Production-ready NPM Package Scanner for Windows PowerShell
    
.DESCRIPTION
    Checks if specific npm packages are used in a repository by scanning
    package.json files and source code for usage patterns.
    
.PARAMETER RepoPath
    Path to the repository to scan
    
.PARAMETER Verbose
    Enable verbose output
    
.PARAMETER Json
    Output results in JSON format
    
.EXAMPLE
    .\check_npm_packages.ps1 -RepoPath "C:\Projects\MyApp"
    
.EXAMPLE
    .\check_npm_packages.ps1 -RepoPath "C:\Projects\MyApp" -Verbose
    
.EXAMPLE
    .\check_npm_packages.ps1 -RepoPath "C:\Projects\MyApp" -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$RepoPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$Json,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Package list to check
$script:Packages = @(
    "ansi-styles@6.2.2",
    "debug@4.4.2",
    "chalk@5.6.1",
    "supports-color@10.2.1",
    "strip-ansi@7.1.1",
    "ansi-regex@6.2.1",
    "wrap-ansi@9.0.1",
    "color-convert@3.1.1",
    "color-name@2.0.1",
    "is-arrayish@0.3.3",
    "slice-ansi@7.1.1",
    "color@5.0.1",
    "color-string@2.1.1",
    "simple-swizzle@0.2.3",
    "supports-hyperlinks@4.1.1",
    "has-ansi@6.0.1",
    "chalk-template@1.1.1",
    "backslash@0.2.1"
)

# Global variables
$script:FoundPackages = @()
$script:NotFoundPackages = @()

# Logging functions
function Write-Info {
    param([string]$Message)
    if ($VerboseOutput -and -not $Json) {
        Write-Host "[INFO] $Message" -ForegroundColor Blue
    }
}

function Write-Success {
    param([string]$Message)
    if (-not $Json) {
        Write-Host "[SUCCESS] $Message" -ForegroundColor Green
    }
}

function Write-Warning {
    param([string]$Message)
    if (-not $Json) {
        Write-Host "[WARNING] $Message" -ForegroundColor Yellow
    }
}

function Write-ErrorMsg {
    param([string]$Message)
    if (-not $Json) {
        Write-Host "[ERROR] $Message" -ForegroundColor Red
    }
}

# Validate repository path
function Test-Repository {
    param([string]$Path)
    
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-ErrorMsg "Repository path does not exist: $Path"
        exit 1
    }
    
    if (-not (Test-Path -Path $Path -PathType Container -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Cannot access repository path: $Path"
        exit 1
    }
}

# Find all package.json files
function Find-PackageFiles {
    param([string]$RootPath)
    
    Write-Info "Searching for package.json files in $RootPath"
    
    try {
        $files = Get-ChildItem -Path $RootPath -Name "package.json" -Recurse -ErrorAction SilentlyContinue | 
                 Select-Object -First 50 |
                 ForEach-Object { Join-Path $RootPath $_ }
        
        return $files
    }
    catch {
        Write-Warning "Error searching for package.json files: $($_.Exception.Message)"
        return @()
    }
}

# Extract package name from package@version format
function Get-PackageName {
    param([string]$PackageSpec)
    
    if ($PackageSpec -match '^(.+)@[^@]+$') {
        return $matches[1]
    }
    return $PackageSpec
}

# Extract version from package@version format
function Get-PackageVersion {
    param([string]$PackageSpec)
    
    if ($PackageSpec -match '^.+@([^@]+)$') {
        return $matches[1]
    }
    return $null
}

# Check if package exists in package.json with version matching
function Test-PackageInFile {
    param(
        [string]$PackageName,
        [string]$ExpectedVersion,
        [string]$FilePath
    )
    
    if (-not (Test-Path -Path $FilePath)) {
        return $null
    }
    
    try {
        $packageJson = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
        
        $sections = @('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies')
        
        foreach ($section in $sections) {
            if ($packageJson.$section -and $packageJson.$section.PSObject.Properties[$PackageName]) {
                $version = $packageJson.$section.$PackageName
                
                # Check if version matches (exact match or range contains the target)
                $versionMatch = $version -eq $ExpectedVersion -or 
                               $version -eq "^$ExpectedVersion" -or 
                               $version -eq "~$ExpectedVersion" -or 
                               $version -eq ">=$ExpectedVersion"
                
                return @{
                    Section = $section
                    Version = $version
                    File = $FilePath
                    VersionMatch = $versionMatch
                    MatchType = if ($versionMatch) { "EXACT_MATCH" } else { "VERSION_MISMATCH" }
                }
            }
        }
        
        return $null
    }
    catch {
        Write-Warning "Error reading $FilePath : $($_.Exception.Message)"
        return $null
    }
}

# Check if package is used in source code
function Test-PackageUsage {
    param(
        [string]$PackageName,
        [string]$RootPath
    )
    
    $patterns = @(
        "require\s*\(\s*[`"']$([regex]::Escape($PackageName))[`"']",
        "import\s+.*\s+from\s+[`"']$([regex]::Escape($PackageName))[`"']",
        "import\s*\([`"']$([regex]::Escape($PackageName))[`"']\)"
    )
    
    $extensions = @('*.js', '*.ts', '*.jsx', '*.tsx', '*.mjs')
    
    try {
        foreach ($pattern in $patterns) {
            foreach ($ext in $extensions) {
                $files = Get-ChildItem -Path $RootPath -Filter $ext -Recurse -ErrorAction SilentlyContinue |
                        Select-Object -First 100
                
                foreach ($file in $files) {
                    try {
                        $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -and $content -match $pattern) {
                            return $true
                        }
                    }
                    catch {
                        # Skip files that can't be read
                        continue
                    }
                }
            }
        }
        
        return $false
    }
    catch {
        Write-Warning "Error checking package usage: $($_.Exception.Message)"
        return $false
    }
}

# Main scanning logic
function Invoke-PackageScan {
    param([string]$RootPath)
    
    $packageFiles = Find-PackageFiles -RootPath $RootPath
    
    if ($packageFiles.Count -eq 0) {
        Write-Warning "No package.json files found in $RootPath"
    }
    else {
        Write-Info "Found $($packageFiles.Count) package.json file(s)"
    }
    
    foreach ($packageSpec in $script:Packages) {
        $packageName = Get-PackageName -PackageSpec $packageSpec
        $expectedVersion = Get-PackageVersion -PackageSpec $packageSpec
        $found = $false
        $versionMatch = $false
        $details = @()
        
        Write-Info "Checking package: $packageName@$expectedVersion"
        
        # Check in package.json files
        foreach ($file in $packageFiles) {
            $result = Test-PackageInFile -PackageName $packageName -ExpectedVersion $expectedVersion -FilePath $file
            if ($result) {
                $found = $true
                $relativeFile = $file -replace [regex]::Escape($RootPath), '.'
                
                if ($result.VersionMatch) {
                    $versionMatch = $true
                    $details += "Found EXACT VERSION in $relativeFile ($($result.Section): $($result.Version))"
                } else {
                    $details += "Found DIFFERENT VERSION in $relativeFile ($($result.Section): $($result.Version))"
                }
            }
        }
        
        # Check if actually used in code
        if (Test-PackageUsage -PackageName $packageName -RootPath $RootPath) {
            if (-not $found) {
                $found = $true
                $details += "Found usage in source code (but not in package.json)"
            }
            else {
                $details += "Also found usage in source code"
            }
        }
        
        if ($found) {
            if ($versionMatch) {
                $script:FoundPackages += @{
                    Name = $packageName
                    Spec = $packageSpec
                    Details = $details
                    VersionMatch = $true
                }
                Write-Success "Package $packageName@$expectedVersion found (exact version match)"
            } else {
                $script:FoundPackages += @{
                    Name = $packageName
                    Spec = $packageSpec
                    Details = $details
                    VersionMatch = $false
                }
                Write-Warning "Package $packageName found but different version than $expectedVersion"
            }
        }
        else {
            $script:NotFoundPackages += @{
                Name = $packageName
                Spec = $packageSpec
            }
            Write-Info "Package $packageName@$expectedVersion not found"
        }
    }
}

# Output results
function Write-Results {
    param([string]$RootPath)
    
    if ($Json) {
        # JSON output
        $result = @{
            repository = $RootPath
            scan_timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            total_packages_checked = $script:Packages.Count
            found_packages = @($script:FoundPackages | ForEach-Object {
                @{
                    name = $_.Name
                    spec = $_.Spec
                }
            })
            not_found_packages = @($script:NotFoundPackages | ForEach-Object {
                @{
                    name = $_.Name
                    spec = $_.Spec
                }
            })
        }
        
        $result | ConvertTo-Json -Depth 10 -Compress:$false
    }
    else {
        # Human-readable output
        Write-Host ""
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "NPM Package Scan Results" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "Repository: $RootPath"
        Write-Host "Scan Date: $(Get-Date)"
        Write-Host "Total Packages Checked: $($script:Packages.Count)"
        Write-Host ""
        
        if ($script:FoundPackages.Count -gt 0) {
            Write-Host "FOUND PACKAGES ($($script:FoundPackages.Count)):" -ForegroundColor Green
            foreach ($package in $script:FoundPackages) {
                Write-Host "✓ $($package.Spec)" -ForegroundColor Green
                if ($VerboseOutput) {
                    foreach ($detail in $package.Details) {
                        Write-Host "  $detail" -ForegroundColor Gray
                    }
                }
            }
            Write-Host ""
        }
        
        if ($script:NotFoundPackages.Count -gt 0) {
            Write-Host "NOT FOUND PACKAGES ($($script:NotFoundPackages.Count)):" -ForegroundColor Yellow
            foreach ($package in $script:NotFoundPackages) {
                Write-Host "✗ $($package.Spec)" -ForegroundColor Yellow
            }
            Write-Host ""
        }
        
        Write-Host "======================================" -ForegroundColor Cyan
    }
}

# Main execution
function Main {
    try {
        Write-Info "Starting NPM package scan"
        Write-Info "Repository: $RepoPath"
        
        # Resolve full path
        $resolvedPath = Resolve-Path -Path $RepoPath -ErrorAction Stop
        
        Test-Repository -Path $resolvedPath
        Invoke-PackageScan -RootPath $resolvedPath
        Write-Results -RootPath $resolvedPath
        
        # Exit with appropriate code
        if ($script:FoundPackages.Count -gt 0) {
            exit 0
        }
        else {
            exit 1
        }
    }
    catch {
        Write-ErrorMsg "Script execution failed: $($_.Exception.Message)"
        if ($VerboseOutput) {
            Write-ErrorMsg "Stack trace: $($_.ScriptStackTrace)"
        }
        exit 1
    }
}

# Run main function
Main
