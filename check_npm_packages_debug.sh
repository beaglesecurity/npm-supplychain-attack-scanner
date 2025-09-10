#!/bin/bash

# Production-ready NPM Package Scanner - DEBUG VERSION
# Checks if specific npm packages are used in a repository
# Usage: ./check_npm_packages_debug.sh <repository_path> [--verbose] [--json] [--debug]
# Compatible with bash 3.2+ (macOS default) and Linux

set -euo pipefail

# Package list to check
declare -a PACKAGES=(
    "ansi-styles@6.2.2"
    "debug@4.4.2"
    "chalk@5.6.1"
    "supports-color@10.2.1"
    "strip-ansi@7.1.1"
    "ansi-regex@6.2.1"
    "wrap-ansi@9.0.1"
    "color-convert@3.1.1"
    "color-name@2.0.1"
    "is-arrayish@0.3.3"
    "slice-ansi@7.1.1"
    "color@5.0.1"
    "color-string@2.1.1"
    "simple-swizzle@0.2.3"
    "supports-hyperlinks@4.1.1"
    "has-ansi@6.0.1"
    "chalk-template@1.1.1"
    "backslash@0.2.1"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
VERBOSE=false
JSON_OUTPUT=false
DEBUG_MODE=false
REPO_PATH=""
FOUND_PACKAGES=()
NOT_FOUND_PACKAGES=()

# Debug logging function
debug_log() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $1" >&2
    fi
}

# System information collection
collect_system_info() {
    debug_log "=== SYSTEM INFORMATION ==="
    debug_log "Operating System: $(uname -a 2>/dev/null || echo 'Unknown')"
    debug_log "Shell: $0"
    debug_log "Bash Version: $BASH_VERSION"
    debug_log "Current User: $(whoami 2>/dev/null || echo 'Unknown')"
    debug_log "Current Directory: $(pwd 2>/dev/null || echo 'Unknown')"
    debug_log "PATH: $PATH"
    debug_log "TMPDIR: ${TMPDIR:-'Not set'}"
    debug_log "TMP: ${TMP:-'Not set'}"
    debug_log "TEMP: ${TEMP:-'Not set'}"
    
    # Check for required tools
    debug_log "=== TOOL VERSIONS ==="
    for tool in jq find grep sed awk timeout; do
        if command -v "$tool" >/dev/null 2>&1; then
            debug_log "$tool: $(command -v "$tool")"
            if [[ "$tool" == "jq" ]]; then
                debug_log "  Version: $(jq --version 2>/dev/null || echo 'Version unknown')"
            elif [[ "$tool" == "find" ]]; then
                debug_log "  Version: $(find --version 2>/dev/null | head -1 || echo 'Version unknown')"
            elif [[ "$tool" == "grep" ]]; then
                debug_log "  Version: $(grep --version 2>/dev/null | head -1 || echo 'Version unknown')"
            elif [[ "$tool" == "sed" ]]; then
                debug_log "  Version: $(sed --version 2>/dev/null | head -1 || echo 'Version unknown')"
            elif [[ "$tool" == "timeout" ]]; then
                debug_log "  Version: $(timeout --version 2>/dev/null | head -1 || echo 'Version unknown')"
            fi
        else
            debug_log "$tool: NOT FOUND"
        fi
    done
    
    # Check file system capabilities
    debug_log "=== FILE SYSTEM CAPABILITIES ==="
    debug_log "Case sensitive filesystem: $(if [[ "test" == "TEST" ]]; then echo "No"; else echo "Yes"; fi)"
    debug_log "Available disk space: $(df -h . 2>/dev/null | tail -1 || echo 'Unknown')"
    
    debug_log "=== END SYSTEM INFORMATION ==="
}

# Usage function
usage() {
    cat << EOF
Usage: $0 <repository_path> [options]

Options:
    --verbose, -v    Enable verbose output
    --json, -j       Output results in JSON format
    --debug, -d      Enable debug mode (shows system info and detailed logging)
    --help, -h       Show this help message

Examples:
    $0 /path/to/repo
    $0 /path/to/repo --verbose
    $0 /path/to/repo --json
    $0 /path/to/repo --debug
EOF
}

# Logging functions
log_info() {
    if [[ "$VERBOSE" == "true" ]] && [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
}

log_success() {
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    fi
}

log_warning() {
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    fi
}

log_error() {
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
}

# Parse command line arguments
parse_args() {
    debug_log "Parsing arguments: $*"
    
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=true
                debug_log "Verbose mode enabled"
                shift
                ;;
            --json|-j)
                JSON_OUTPUT=true
                debug_log "JSON output mode enabled"
                shift
                ;;
            --debug|-d)
                DEBUG_MODE=true
                debug_log "Debug mode enabled"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$REPO_PATH" ]]; then
                    REPO_PATH="$1"
                    debug_log "Repository path set to: $REPO_PATH"
                else
                    log_error "Multiple repository paths provided"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$REPO_PATH" ]]; then
        log_error "Repository path is required"
        usage
        exit 1
    fi
}

# Validate repository path
validate_repo() {
    debug_log "Validating repository path: $REPO_PATH"
    
    if [[ ! -d "$REPO_PATH" ]]; then
        log_error "Repository path does not exist: $REPO_PATH"
        debug_log "Directory check failed - path does not exist"
        exit 1
    fi

    if [[ ! -r "$REPO_PATH" ]]; then
        log_error "Cannot read repository path: $REPO_PATH"
        debug_log "Read permission check failed"
        exit 1
    fi
    
    debug_log "Repository path validation successful"
    debug_log "Repository contents: $(ls -la "$REPO_PATH" 2>/dev/null | head -10 || echo 'Cannot list contents')"
}

# Find all package.json files (excluding node_modules for better performance)
find_package_files() {
    debug_log "Searching for package.json files in $REPO_PATH"
    
    local find_cmd="find \"$REPO_PATH\" -name \"package.json\" -type f -not -path \"*/node_modules/*\" 2>/dev/null"
    debug_log "Find command: $find_cmd"
    
    # Test find command
    local find_output
    if find_output=$(eval "$find_cmd" 2>&1); then
        debug_log "Find command successful"
        debug_log "Find output: $find_output"
        echo "$find_output" | head -10
    else
        debug_log "Find command failed with exit code: $?"
        debug_log "Find error output: $find_output"
        echo ""
    fi
}

# Extract package name from package@version format
get_package_name() {
    local input="$1"
    debug_log "Extracting package name from: $input"
    
    local result
    if result=$(echo "$input" | sed 's/@[^@]*$//' 2>&1); then
        debug_log "Package name extracted: $result"
        echo "$result"
    else
        debug_log "Failed to extract package name: $result"
        echo "$input"
    fi
}

# Extract version from package@version format
get_package_version() {
    local input="$1"
    debug_log "Extracting package version from: $input"
    
    local result
    if result=$(echo "$input" | sed -n 's/^.*@\([^@]*\)$/\1/p' 2>&1); then
        debug_log "Package version extracted: $result"
        echo "$result"
    else
        debug_log "Failed to extract package version: $result"
        echo ""
    fi
}

# Check if package exists in package.json with version matching
check_package_in_file() {
    local package_name="$1"
    local expected_version="$2"
    local file="$3"
    
    debug_log "Checking package $package_name@$expected_version in file: $file"
    
    if [[ ! -f "$file" ]]; then
        debug_log "File does not exist: $file"
        return 1
    fi

    debug_log "File exists, checking permissions..."
    if [[ ! -r "$file" ]]; then
        debug_log "File is not readable: $file"
        return 1
    fi

    # Check all dependency sections
    local sections=("dependencies" "devDependencies" "peerDependencies" "optionalDependencies")
    
    for section in "${sections[@]}"; do
        debug_log "Checking section: $section"
        
        # Test jq command first
        local jq_test_cmd="jq -e \".${section} | has(\\\"${package_name}\\\")\" \"$file\""
        debug_log "JQ test command: $jq_test_cmd"
        
        # Use timeout to prevent hanging (if available)
        if command -v timeout >/dev/null 2>&1; then
            debug_log "Using timeout for jq commands"
            local jq_result
            if jq_result=$(timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
                debug_log "Package found in $section"
                local version
                if version=$(timeout 5 jq -r ".${section}[\"${package_name}\"]" "$file" 2>&1); then
                    debug_log "Version retrieved: $version"
                    
                    if [[ -n "$version" && "$version" != "null" ]]; then
                        # Check if version matches (exact match or range contains the target)
                        debug_log "Checking version match: '$version' vs '$expected_version'"
                        if [[ "$version" == "$expected_version" ]] || [[ "$version" == "^$expected_version" ]] || 
                           [[ "$version" == "~$expected_version" ]] || [[ "$version" == ">=$expected_version" ]]; then
                            debug_log "Version match found!"
                            echo "$section:$version:EXACT_MATCH"
                            return 0
                        else
                            debug_log "Version mismatch: found '$version', expected '$expected_version'"
                            echo "$section:$version:VERSION_MISMATCH"
                            return 2  # Found package but version doesn't match
                        fi
                    else
                        debug_log "Version is null or empty"
                    fi
                else
                    debug_log "Failed to get version: $version"
                fi
            else
                debug_log "Package not found in $section: $jq_result"
            fi
        else
            debug_log "Timeout not available, using jq directly"
            local jq_result
            if jq_result=$(jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
                debug_log "Package found in $section"
                local version
                if version=$(jq -r ".${section}[\"${package_name}\"]" "$file" 2>&1); then
                    debug_log "Version retrieved: $version"
                    
                    if [[ -n "$version" && "$version" != "null" ]]; then
                        # Check if version matches (exact match or range contains the target)
                        debug_log "Checking version match: '$version' vs '$expected_version'"
                        if [[ "$version" == "$expected_version" ]] || [[ "$version" == "^$expected_version" ]] || 
                           [[ "$version" == "~$expected_version" ]] || [[ "$version" == ">=$expected_version" ]]; then
                            debug_log "Version match found!"
                            echo "$section:$version:EXACT_MATCH"
                            return 0
                        else
                            debug_log "Version mismatch: found '$version', expected '$expected_version'"
                            echo "$section:$version:VERSION_MISMATCH"
                            return 2  # Found package but version doesn't match
                        fi
                    else
                        debug_log "Version is null or empty"
                    fi
                else
                    debug_log "Failed to get version: $version"
                fi
            else
                debug_log "Package not found in $section: $jq_result"
            fi
        fi
    done
    
    debug_log "Package not found in any section"
    return 1  # Package not found
}

# Check if package is used in source code
check_package_usage() {
    local package_name="$1"
    debug_log "Checking package usage in source code: $package_name"
    
    # Common import patterns
    local patterns=(
        "require\\s*\\(\\s*['\"]${package_name}['\"]"
        "import\\s+.*\\s+from\\s+['\"]${package_name}['\"]"
        "import\\s*\\(['\"]${package_name}['\"]\\)"
    )
    
    for pattern in "${patterns[@]}"; do
        debug_log "Searching for pattern: $pattern"
        local grep_cmd="grep -r -l --include=\"*.js\" --include=\"*.ts\" --include=\"*.jsx\" --include=\"*.tsx\" --include=\"*.mjs\" -E \"$pattern\" \"$REPO_PATH\""
        debug_log "Grep command: $grep_cmd"
        
        if grep -r -l --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" --include="*.mjs" \
           -E "$pattern" "$REPO_PATH" >/dev/null 2>&1; then
            debug_log "Pattern found in source code"
            return 0
        else
            debug_log "Pattern not found in source code"
        fi
    done
    
    debug_log "Package not found in source code"
    return 1
}

# Main scanning logic
scan_packages() {
    debug_log "Starting package scan"
    local package_files=()
    
    # Compatible with bash 3.2+ (macOS default) and Linux
    debug_log "Creating temporary file for package files"
    local temp_file
    if temp_file=$(mktemp 2>&1); then
        debug_log "Temporary file created: $temp_file"
    else
        debug_log "Failed to create temporary file: $temp_file"
        log_error "Failed to create temporary file"
        exit 1
    fi
    
    debug_log "Finding package files and storing in temp file"
    find_package_files | head -50 > "$temp_file"
    
    # Debug: Check temp file content
    debug_log "Temp file path: $temp_file"
    debug_log "Temp file size: $(wc -l < "$temp_file" 2>/dev/null || echo '0') lines"
    debug_log "Temp file content:"
    debug_log "$(cat "$temp_file" 2>/dev/null || echo 'Could not read temp file')"
    
    debug_log "Reading package files from temp file"
    local file_count=0
    
    # More robust file reading that works across different bash versions
    if [[ -s "$temp_file" ]]; then
        debug_log "Temp file has content, reading files..."
        
        # Try the standard method first
        while IFS= read -r file || [[ -n "$file" ]]; do
            if [[ -n "$file" ]]; then
                package_files+=("$file")
                ((file_count++))
                debug_log "Added package file $file_count: $file"
            fi
        done < "$temp_file"
        
        # If no files were read, try alternative method
        if [[ $file_count -eq 0 ]]; then
            debug_log "No files read with standard method, trying alternative..."
            # Alternative method using mapfile (bash 4.0+)
            if command -v mapfile >/dev/null 2>&1; then
                debug_log "Using mapfile method"
                mapfile -t temp_files < "$temp_file"
                for file in "${temp_files[@]}"; do
                    if [[ -n "$file" ]]; then
                        package_files+=("$file")
                        ((file_count++))
                        debug_log "Added package file $file_count: $file"
                    fi
                done
            else
                debug_log "Using cat + readarray method"
                # Fallback: use cat and readarray
                local temp_content
                temp_content=$(cat "$temp_file" 2>/dev/null)
                if [[ -n "$temp_content" ]]; then
                    while IFS=$'\n' read -r file; do
                        if [[ -n "$file" ]]; then
                            package_files+=("$file")
                            ((file_count++))
                            debug_log "Added package file $file_count: $file"
                        fi
                    done <<< "$temp_content"
                fi
            fi
        fi
        
        debug_log "Finished reading files from temp file"
    else
        debug_log "Temp file is empty or doesn't exist"
    fi
    
    debug_log "Cleaning up temporary file"
    rm -f "$temp_file"
    
    debug_log "Total package files found: ${#package_files[@]}"
    
    if [[ ${#package_files[@]} -eq 0 ]]; then
        log_warning "No package.json files found in $REPO_PATH"
    else
        log_info "Found ${#package_files[@]} package.json file(s)"
    fi

    for package_spec in "${PACKAGES[@]}"; do
        debug_log "=== PROCESSING PACKAGE: $package_spec ==="
        
        local package_name
        local expected_version
        package_name=$(get_package_name "$package_spec")
        expected_version=$(get_package_version "$package_spec")
        local found=false
        local version_match=false
        local details=""
        
        debug_log "Package name: $package_name"
        debug_log "Expected version: $expected_version"
        
        log_info "Checking package: $package_name@$expected_version"
        
        # Check in package.json files (limit to avoid node_modules overload)
        local checked_files=0
        if [[ ${#package_files[@]} -gt 0 ]]; then
            debug_log "Checking in ${#package_files[@]} package.json files"
            for file in "${package_files[@]}"; do
                if [[ $checked_files -ge 10 ]]; then
                    debug_log "Reached file limit (10), stopping"
                    break
                fi
                
                debug_log "Checking file $((checked_files + 1)): $file"
                log_info "  Checking file: $(basename "$file")"
                
                # Check each dependency section for exact version match
                local sections=("dependencies" "devDependencies" "peerDependencies" "optionalDependencies")
                local file_found=false
                
                for section in "${sections[@]}"; do
                    debug_log "  Checking section: $section"
                    
                    # Check if package exists in this section
                    if command -v timeout >/dev/null 2>&1; then
                        debug_log "  Using timeout for jq commands"
                        local jq_result
                        if jq_result=$(timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
                            debug_log "  Package found in $section"
                            # Get the version
                            local version
                            if version=$(timeout 5 jq -r ".${section}[\"${package_name}\"]" "$file" 2>&1); then
                                debug_log "  Version retrieved: $version"
                                
                                if [[ -n "$version" && "$version" != "null" ]]; then
                                    file_found=true
                                    log_info "    Found in $section: $version"
                                    
                                    # Check if version matches exactly or in acceptable range
                                    debug_log "  Checking version match: '$version' vs '$expected_version'"
                                    if [[ "$version" == "$expected_version" ]] || 
                                       [[ "$version" == "^$expected_version" ]] || 
                                       [[ "$version" == "~$expected_version" ]] || 
                                       [[ "$version" == ">=$expected_version" ]]; then
                                        found=true
                                        version_match=true
                                        details="$details\n  EXACT VERSION MATCH in $(basename "$file") ($section: $version)"
                                        log_info "    ✓ VERSION MATCH!"
                                        debug_log "  VERSION MATCH FOUND!"
                                    else
                                        found=true
                                        details="$details\n  DIFFERENT VERSION in $(basename "$file") ($section: $version, expected: $expected_version)"
                                        log_info "    ✗ Different version"
                                        debug_log "  VERSION MISMATCH"
                                    fi
                                    break
                                else
                                    debug_log "  Version is null or empty"
                                fi
                            else
                                debug_log "  Failed to get version: $version"
                            fi
                        else
                            debug_log "  Package not found in $section: $jq_result"
                        fi
                    else
                        debug_log "  Timeout not available, using jq directly"
                        local jq_result
                        if jq_result=$(jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
                            debug_log "  Package found in $section"
                            # Get the version
                            local version
                            if version=$(jq -r ".${section}[\"${package_name}\"]" "$file" 2>&1); then
                                debug_log "  Version retrieved: $version"
                                
                                if [[ -n "$version" && "$version" != "null" ]]; then
                                    file_found=true
                                    log_info "    Found in $section: $version"
                                    
                                    # Check if version matches exactly or in acceptable range
                                    debug_log "  Checking version match: '$version' vs '$expected_version'"
                                    if [[ "$version" == "$expected_version" ]] || 
                                       [[ "$version" == "^$expected_version" ]] || 
                                       [[ "$version" == "~$expected_version" ]] || 
                                       [[ "$version" == ">=$expected_version" ]]; then
                                        found=true
                                        version_match=true
                                        details="$details\n  EXACT VERSION MATCH in $(basename "$file") ($section: $version)"
                                        log_info "    ✓ VERSION MATCH!"
                                        debug_log "  VERSION MATCH FOUND!"
                                    else
                                        found=true
                                        details="$details\n  DIFFERENT VERSION in $(basename "$file") ($section: $version, expected: $expected_version)"
                                        log_info "    ✗ Different version"
                                        debug_log "  VERSION MISMATCH"
                                    fi
                                    break
                                else
                                    debug_log "  Version is null or empty"
                                fi
                            else
                                debug_log "  Failed to get version: $version"
                            fi
                        else
                            debug_log "  Package not found in $section: $jq_result"
                        fi
                    fi
                done
                
                if [[ "$file_found" == "false" ]]; then
                    log_info "    Package not found in any dependency section"
                    debug_log "  Package not found in any section of this file"
                fi
                
                ((checked_files++))
            done
        fi
        
        # Check if actually used in code (only if not found in package.json)
        debug_log "Checking source code usage for package: $package_name"
        if [[ "$found" == "false" ]] && check_package_usage "$package_name"; then
            found=true
            details="$details\n  Found usage in source code (but not in package.json - possible transitive dependency)"
            debug_log "Package found in source code but not in package.json"
        elif [[ "$found" == "true" ]] && check_package_usage "$package_name"; then
            details="$details\n  Also confirmed usage in source code"
            debug_log "Package found in both package.json and source code"
        fi
        
        if [[ "$found" == "true" ]]; then
            if [[ "$version_match" == "true" ]]; then
                FOUND_PACKAGES+=("$package_spec:$details:EXACT_VERSION")
                log_success "Package $package_name@$expected_version found (EXACT VERSION MATCH)"
                debug_log "Package added to FOUND_PACKAGES with EXACT_VERSION"
            else
                FOUND_PACKAGES+=("$package_spec:$details:DIFFERENT_VERSION")
                log_warning "Package $package_name found but DIFFERENT VERSION than $expected_version"
                debug_log "Package added to FOUND_PACKAGES with DIFFERENT_VERSION"
            fi
        else
            NOT_FOUND_PACKAGES+=("$package_spec")
            log_info "Package $package_name@$expected_version not found"
            debug_log "Package added to NOT_FOUND_PACKAGES"
        fi
        
        debug_log "=== END PROCESSING PACKAGE: $package_spec ==="
    done
}

# Output results
output_results() {
    debug_log "Outputting results"
    debug_log "JSON_OUTPUT: $JSON_OUTPUT"
    debug_log "FOUND_PACKAGES count: ${#FOUND_PACKAGES[@]}"
    debug_log "NOT_FOUND_PACKAGES count: ${#NOT_FOUND_PACKAGES[@]}"
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        # JSON output
        debug_log "Generating JSON output"
        echo "{"
        echo "  \"repository\": \"$REPO_PATH\","
        echo "  \"scan_timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')\","
        echo "  \"total_packages_checked\": ${#PACKAGES[@]},"
        echo "  \"found_packages\": ["
        
        local first=true
        if [[ ${#FOUND_PACKAGES[@]} -gt 0 ]]; then
            for package_info in "${FOUND_PACKAGES[@]}"; do
            if [[ "$first" == "false" ]]; then
                echo ","
            fi
            local package_spec="${package_info%%:*}"
            local package_name
            package_name=$(get_package_name "$package_spec")
            echo -n "    {\"name\": \"$package_name\", \"spec\": \"$package_spec\"}"
            first=false
            done
        fi
        
        echo ""
        echo "  ],"
        echo "  \"not_found_packages\": ["
        
        first=true
        if [[ ${#NOT_FOUND_PACKAGES[@]} -gt 0 ]]; then
            for package_spec in "${NOT_FOUND_PACKAGES[@]}"; do
            if [[ "$first" == "false" ]]; then
                echo ","
            fi
            local package_name
            package_name=$(get_package_name "$package_spec")
            echo -n "    {\"name\": \"$package_name\", \"spec\": \"$package_spec\"}"
            first=false
            done
        fi
        
        echo ""
        echo "  ]"
        echo "}"
    else
        # Human-readable output
        debug_log "Generating human-readable output"
        echo ""
        echo "======================================"
        echo "NPM Package Scan Results"
        echo "======================================"
        echo "Repository: $REPO_PATH"
        echo "Scan Date: $(date '+%a %b %d %H:%M:%S %Z %Y' 2>/dev/null || date)"
        echo "Total Packages Checked: ${#PACKAGES[@]}"
        echo ""
        
        if [[ ${#FOUND_PACKAGES[@]} -gt 0 ]]; then
            echo -e "${GREEN}FOUND PACKAGES (${#FOUND_PACKAGES[@]}):${NC}"
            for package_info in "${FOUND_PACKAGES[@]}"; do
                local package_spec="${package_info%%:*}"
                local rest="${package_info#*:}"
                local details="${rest%:*}"
                local match_type="${rest##*:}"
                
                if [[ "$match_type" == "EXACT_VERSION" ]]; then
                    echo -e "${GREEN}✓ $package_spec (EXACT VERSION MATCH)${NC}"
                else
                    echo -e "${YELLOW}⚠ $package_spec (DIFFERENT VERSION)${NC}"
                fi
                
                if [[ "$VERBOSE" == "true" ]]; then
                    echo -e "$details"
                fi
            done
            echo ""
        fi
        
        if [[ ${#NOT_FOUND_PACKAGES[@]} -gt 0 ]]; then
            echo -e "${YELLOW}NOT FOUND PACKAGES (${#NOT_FOUND_PACKAGES[@]}):${NC}"
            for package_spec in "${NOT_FOUND_PACKAGES[@]}"; do
                echo "✗ $package_spec"
            done
            echo ""
        fi
        
        echo "======================================"
    fi
}

# Main function
main() {
    debug_log "=== SCRIPT START ==="
    debug_log "Arguments: $*"
    
    parse_args "$@"
    
    # Collect system information if debug mode is enabled
    if [[ "$DEBUG_MODE" == "true" ]]; then
        collect_system_info
    fi
    
    validate_repo
    
    # Check for required tools
    debug_log "Checking for required tools"
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not installed. Please install jq first."
        debug_log "jq not found in PATH: $PATH"
        exit 1
    fi
    debug_log "jq found: $(command -v jq)"
    
    log_info "Starting NPM package scan"
    log_info "Repository: $REPO_PATH"
    
    scan_packages
    output_results
    
    debug_log "=== SCRIPT END ==="
    debug_log "Final results: FOUND=${#FOUND_PACKAGES[@]}, NOT_FOUND=${#NOT_FOUND_PACKAGES[@]}"
    
    # Exit with appropriate code
    if [[ ${#FOUND_PACKAGES[@]} -gt 0 ]]; then
        debug_log "Exiting with code 0 (packages found)"
        exit 0
    else
        debug_log "Exiting with code 1 (no packages found)"
        exit 1
    fi
}

# Run main function
main "$@"
