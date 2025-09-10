# Debug Guide for NPM Supply Chain Attack Scanner

## Overview
The debug version (`check_npm_packages_debug.sh`) has been created to help identify why the shell script works on Mac but not on Linux. This guide explains how to use it effectively.

## Usage

### Basic Debug Mode
```bash
./check_npm_packages_debug.sh <repository_path> --debug
```

### Debug with Verbose Output
```bash
./check_npm_packages_debug.sh <repository_path> --debug --verbose
```

### Debug with JSON Output
```bash
./check_npm_packages_debug.sh <repository_path> --debug --json
```

## What the Debug Version Provides

### 1. System Information Collection
The debug version collects comprehensive system information including:
- Operating System details (`uname -a`)
- Shell version and path
- Bash version
- Current user and directory
- PATH environment variable
- Temporary directory settings (TMPDIR, TMP, TEMP)
- Tool versions (jq, find, grep, sed, awk, timeout)
- File system capabilities (case sensitivity, disk space)

### 2. Command Execution Debugging
Every external command is logged with:
- The exact command being executed
- Success/failure status
- Output and error messages
- Exit codes

### 3. Step-by-Step Process Logging
Detailed logging for:
- Argument parsing
- Repository validation
- Package file discovery
- Package name/version extraction
- JSON parsing with jq
- Version matching logic
- Source code searching with grep
- Result compilation

### 4. Error Handling
Enhanced error messages that show:
- What operation failed
- Why it failed
- What was expected vs. what was found
- System state at the time of failure

## Common Issues to Look For

### 1. Tool Availability
- **jq**: Required for JSON parsing
- **timeout**: Used to prevent hanging commands
- **find**: Used for file discovery
- **grep**: Used for source code searching

### 2. Path Differences
- Different tool locations between Mac and Linux
- Different PATH configurations
- Different temporary directory locations

### 3. Tool Version Differences
- Different jq versions may have different syntax support
- Different grep versions may have different regex support
- Different find versions may have different options

### 4. File System Differences
- Case sensitivity differences
- Permission differences
- Path separator differences

### 5. Shell Compatibility
- Different bash versions
- Different shell features available
- Different default behaviors

## How to Use for Troubleshooting

### Step 1: Run on Mac (Working Environment)
```bash
./check_npm_packages_debug.sh test-repo --debug > mac_debug.log 2>&1
```

### Step 2: Run on Linux (Failing Environment)
```bash
./check_npm_packages_debug.sh test-repo --debug > linux_debug.log 2>&1
```

### Step 3: Compare the Logs
Look for differences in:
- System information section
- Tool versions
- Command execution results
- Error messages
- File paths and permissions

### Step 4: Identify the Root Cause
Common patterns to look for:
- Missing tools or different versions
- Different command syntax requirements
- Permission issues
- Path resolution problems
- Shell compatibility issues

## Example Debug Output Analysis

### System Information Section
```
[DEBUG] === SYSTEM INFORMATION ===
[DEBUG] Operating System: Linux ubuntu 5.4.0-42-generic #46-Ubuntu SMP Fri Jul 10 00:24:02 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
[DEBUG] Shell: /bin/bash
[DEBUG] Bash Version: 4.4.20(1)-release
[DEBUG] jq: /usr/bin/jq
[DEBUG]   Version: jq-1.5-1-a5b5cbe
```

### Command Execution
```
[DEBUG] JQ test command: jq -e ".dependencies | has(\"ansi-styles\")" "test-repo/package.json"
[DEBUG] Package found in dependencies
[DEBUG] Version retrieved: 6.2.2
```

### Error Detection
```
[DEBUG] Failed to get version: parse error: Invalid numeric literal at line 1, column 1
[DEBUG] JQ error: parse error: Invalid numeric literal at line 1, column 1
```

## Troubleshooting Tips

1. **Check Tool Versions**: Compare jq, grep, and other tool versions between Mac and Linux
2. **Verify File Permissions**: Ensure the script has read access to the repository
3. **Test Individual Commands**: Run the jq and grep commands manually to see if they work
4. **Check Shell Compatibility**: Verify that the bash version supports all features used
5. **Examine Error Messages**: Look for specific error messages that indicate the root cause

## Quick Fixes for Common Issues

### Missing jq
```bash
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq
```

### Missing timeout
```bash
# Ubuntu/Debian
sudo apt-get install coreutils

# CentOS/RHEL
sudo yum install coreutils
```

### Permission Issues
```bash
chmod +x check_npm_packages_debug.sh
```

### Shell Compatibility
```bash
# Use bash explicitly
bash check_npm_packages_debug.sh test-repo --debug
```

## Reporting Issues

When reporting issues, please include:
1. The complete debug output from both Mac and Linux
2. System information (OS, shell version, tool versions)
3. The specific error messages
4. Steps to reproduce the issue

This will help identify the exact cause of the compatibility problem.
