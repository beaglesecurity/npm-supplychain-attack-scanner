# NPM Package Scanner

Production-ready scripts to scan repositories for specific NPM packages.

## Features

- **Cross-platform**: Shell script for Unix/Linux/macOS and PowerShell for Windows
- **Version-aware scanning**: Checks both package names AND specific versions
- **Comprehensive scanning**: Checks package.json files AND source code usage
- **Multiple output formats**: Human-readable and JSON output
- **Production-ready**: Error handling, validation, logging, and proper exit codes
- **Performance optimized**: Limits search scope to prevent infinite recursion
- **Tested and verified**: Both scripts produce identical results

## Scripts

- `check_npm_packages.sh` - Shell script for Unix/Linux/macOS
- `check_npm_packages.ps1` - PowerShell script for Windows

## Scanned Packages

The scripts check for these packages:
- ansi-styles@6.2.2
- debug@4.4.2
- chalk@5.6.1
- supports-color@10.2.1
- strip-ansi@7.1.1
- ansi-regex@6.2.1
- wrap-ansi@9.0.1
- color-convert@3.1.1
- color-name@2.0.1
- is-arrayish@0.3.3
- slice-ansi@7.1.1
- color@5.0.1
- color-string@2.1.1
- simple-swizzle@0.2.3
- supports-hyperlinks@4.1.1
- has-ansi@6.0.1
- chalk-template@1.1.1
- backslash@0.2.1

## Requirements

### Shell Script (`check_npm_packages.sh`)
- Bash 3.2+ (compatible with macOS default bash and Linux)
- `jq` command-line JSON processor
- Standard Unix tools (find, grep, sed, mktemp)
- `timeout` command (optional, for performance optimization)

Install jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq
```

### PowerShell Script (`check_npm_packages.ps1`)
- PowerShell 5.1 or later
- Windows, macOS, or Linux with PowerShell Core

## Usage

### Shell Script

```bash
# Basic usage
./check_npm_packages.sh /path/to/repository

# With verbose output
./check_npm_packages.sh /path/to/repository --verbose

# JSON output
./check_npm_packages.sh /path/to/repository --json

# Help
./check_npm_packages.sh --help
```

### PowerShell Script

```powershell
# Basic usage
.\check_npm_packages.ps1 -RepoPath "C:\path\to\repository"

# With verbose output
.\check_npm_packages.ps1 -RepoPath "C:\path\to\repository" -VerboseOutput

# JSON output
.\check_npm_packages.ps1 -RepoPath "C:\path\to\repository" -Json

# Help
Get-Help .\check_npm_packages.ps1 -Full
```

## Output

### Human-Readable Format

```
======================================
NPM Package Scan Results
======================================
Repository: /path/to/repo
Scan Date: Wed Sep 10 2025 10:30:00
Total Packages Checked: 18

FOUND PACKAGES (3):
✓ chalk@5.6.1
✓ debug@4.4.2
✓ supports-color@10.2.1

NOT FOUND PACKAGES (15):
✗ ansi-styles@6.2.2
✗ strip-ansi@7.1.1
...
======================================
```

### JSON Format

```json
{
  "repository": "/path/to/repo",
  "scan_timestamp": "2025-09-10T10:30:00Z",
  "total_packages_checked": 18,
  "found_packages": [
    {"name": "chalk", "spec": "chalk@5.6.1"},
    {"name": "debug", "spec": "debug@4.4.2"}
  ],
  "not_found_packages": [
    {"name": "ansi-styles", "spec": "ansi-styles@6.2.2"}
  ]
}
```

## Exit Codes

- `0` - Success: One or more packages found
- `1` - No packages found or error occurred

## What Gets Scanned

1. **package.json files**: All dependency sections (dependencies, devDependencies, peerDependencies, optionalDependencies) with exact version matching
2. **Source code**: JavaScript/TypeScript files for import/require statements
3. **File types checked**: .js, .ts, .jsx, .tsx, .mjs
4. **Version checking**: Supports exact matches and common version ranges (^, ~, >=)

## Performance Considerations

### Shell Script
- Limits to first 10 package.json files found (configurable)
- Uses `timeout` commands to prevent hanging on large files
- Efficient regex patterns for code scanning
- Early termination where possible

### PowerShell Script
- Limits to first 50 package.json files found
- Limits to first 100 source files per extension when checking usage
- Uses efficient regex patterns for code scanning
- Implements early termination where possible

## Error Handling

Both scripts include comprehensive error handling for:
- Invalid repository paths
- Permission issues
- Missing dependencies (jq for shell script)
- Malformed JSON files
- File system errors
- Empty directories (no package.json files)
- Array bounds checking (shell script)

### Shell Script Specific
- Requires `jq` command-line JSON processor
- Uses `timeout` to prevent hanging on large files (when available)
- Handles empty arrays gracefully
- Uses temporary files instead of process substitution for Linux compatibility
- Fallback date command handling for different Linux distributions

## Customization

To modify the package list, edit the `PACKAGES` array in the shell script or `$script:Packages` array in the PowerShell script.

## Recent Updates

- **Linux compatibility**: Fixed date command and timeout command compatibility issues
- **Process substitution**: Replaced with temporary files for better Linux compatibility
- **Bug fixes**: Fixed array bounds checking issues in shell script
- **Improved error handling**: Better handling of empty directories and missing files
- **Performance optimizations**: Added timeout protection for large files (when available)
- **Testing**: Comprehensive test suite validates both scripts produce identical results

## Integration

These scripts can be easily integrated into:
- CI/CD pipelines
- Automated security scans
- Dependency auditing workflows
- Build processes

Example CI integration:
```bash
# In your CI script
if ./check_npm_packages.sh "$REPO_PATH" --json > scan_results.json; then
  echo "Vulnerable packages found, see scan_results.json"
  exit 1
fi
```
