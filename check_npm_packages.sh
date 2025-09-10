#!/bin/bash

# Production-ready NPM Package Scanner
# Checks if specific npm packages are used in a repository
# Usage: ./check_npm_packages.sh <repository_path> [--verbose] [--json]
# Compatible with bash 3.2+ (macOS default)

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
NC='\033[0m' # No Color

# Global variables
VERBOSE=false
JSON_OUTPUT=false
REPO_PATH=""
FOUND_PACKAGES=()
NOT_FOUND_PACKAGES=()

# Usage function
usage() {
    cat << EOF
Usage: $0 <repository_path> [options]

Options:
    --verbose, -v    Enable verbose output
    --json, -j       Output results in JSON format
    --help, -h       Show this help message

Examples:
    $0 /path/to/repo
    $0 /path/to/repo --verbose
    $0 /path/to/repo --json
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
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --json|-j)
                JSON_OUTPUT=true
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
    if [[ ! -d "$REPO_PATH" ]]; then
        log_error "Repository path does not exist: $REPO_PATH"
        exit 1
    fi

    if [[ ! -r "$REPO_PATH" ]]; then
        log_error "Cannot read repository path: $REPO_PATH"
        exit 1
    fi
}

# Find all package.json files (excluding node_modules for better performance)
find_package_files() {
    log_info "Searching for package.json files in $REPO_PATH"
    find "$REPO_PATH" -name "package.json" -type f -not -path "*/node_modules/*" 2>/dev/null | head -10
}

# Extract package name from package@version format
get_package_name() {
    echo "$1" | sed 's/@[^@]*$//'
}

# Extract version from package@version format
get_package_version() {
    echo "$1" | sed -n 's/^.*@\([^@]*\)$/\1/p'
}

# Check if package exists in package.json with version matching
check_package_in_file() {
    local package_name="$1"
    local expected_version="$2"
    local file="$3"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Check all dependency sections
    local sections=("dependencies" "devDependencies" "peerDependencies" "optionalDependencies")
    
    for section in "${sections[@]}"; do
        # Use timeout to prevent hanging (if available)
        if command -v timeout >/dev/null 2>&1; then
            if timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" >/dev/null 2>&1; then
                local version
                version=$(timeout 5 jq -r ".${section}[\"${package_name}\"]" "$file" 2>/dev/null)
                
                if [[ -n "$version" && "$version" != "null" ]]; then
                    # Check if version matches (exact match or range contains the target)
                    if [[ "$version" == "$expected_version" ]] || [[ "$version" == "^$expected_version" ]] || 
                       [[ "$version" == "~$expected_version" ]] || [[ "$version" == ">=$expected_version" ]]; then
                        echo "$section:$version:EXACT_MATCH"
                        return 0
                    else
                        echo "$section:$version:VERSION_MISMATCH"
                        return 2  # Found package but version doesn't match
                    fi
                fi
            fi
        else
            if jq -e ".${section} | has(\"${package_name}\")" "$file" >/dev/null 2>&1; then
                local version
                version=$(jq -r ".${section}[\"${package_name}\"]" "$file" 2>/dev/null)
                
                if [[ -n "$version" && "$version" != "null" ]]; then
                    # Check if version matches (exact match or range contains the target)
                    if [[ "$version" == "$expected_version" ]] || [[ "$version" == "^$expected_version" ]] || 
                       [[ "$version" == "~$expected_version" ]] || [[ "$version" == ">=$expected_version" ]]; then
                        echo "$section:$version:EXACT_MATCH"
                        return 0
                    else
                        echo "$section:$version:VERSION_MISMATCH"
                        return 2  # Found package but version doesn't match
                    fi
                fi
            fi
        fi
    done
    
    return 1  # Package not found
}

# Check if package is used in source code
check_package_usage() {
    local package_name="$1"
    
    # Common import patterns
    local patterns=(
        "require\\s*\\(\\s*['\"]${package_name}['\"]"
        "import\\s+.*\\s+from\\s+['\"]${package_name}['\"]"
        "import\\s*\\(['\"]${package_name}['\"]\\)"
    )
    
    for pattern in "${patterns[@]}"; do
        if grep -r -l --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" --include="*.mjs" \
           -E "$pattern" "$REPO_PATH" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}

# Main scanning logic
scan_packages() {
    local package_files=()
    
    # Compatible with bash 3.2+ (macOS default) and Linux
    local temp_file=$(mktemp)
    find_package_files | head -50 > "$temp_file"
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            package_files+=("$file")
        fi
    done < "$temp_file"
    rm -f "$temp_file"
    
    if [[ ${#package_files[@]} -eq 0 ]]; then
        log_warning "No package.json files found in $REPO_PATH"
    else
        log_info "Found ${#package_files[@]} package.json file(s)"
    fi

    for package_spec in "${PACKAGES[@]}"; do
        local package_name
        local expected_version
        package_name=$(get_package_name "$package_spec")
        expected_version=$(get_package_version "$package_spec")
        local found=false
        local version_match=false
        local details=""
        
        log_info "Checking package: $package_name@$expected_version"
        
        # Check in package.json files (limit to avoid node_modules overload)
        local checked_files=0
        if [[ ${#package_files[@]} -gt 0 ]]; then
            for file in "${package_files[@]}"; do
            if [[ $checked_files -ge 10 ]]; then
                break
            fi
            
            log_info "  Checking file: $(basename "$file")"
            # Check each dependency section for exact version match
            local sections=("dependencies" "devDependencies" "peerDependencies" "optionalDependencies")
            local file_found=false
            
            for section in "${sections[@]}"; do
                # Check if package exists in this section
                if command -v timeout >/dev/null 2>&1; then
                    if timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" >/dev/null 2>&1; then
                        # Get the version
                        local version=$(timeout 5 jq -r ".${section}[\"${package_name}\"]" "$file" 2>/dev/null)
                        
                        if [[ -n "$version" && "$version" != "null" ]]; then
                            file_found=true
                            log_info "    Found in $section: $version"
                            
                            # Check if version matches exactly or in acceptable range
                            if [[ "$version" == "$expected_version" ]] || 
                               [[ "$version" == "^$expected_version" ]] || 
                               [[ "$version" == "~$expected_version" ]] || 
                               [[ "$version" == ">=$expected_version" ]]; then
                                found=true
                                version_match=true
                                details="$details\n  EXACT VERSION MATCH in $(basename "$file") ($section: $version)"
                                log_info "    ✓ VERSION MATCH!"
                            else
                                found=true
                                details="$details\n  DIFFERENT VERSION in $(basename "$file") ($section: $version, expected: $expected_version)"
                                log_info "    ✗ Different version"
                            fi
                            break
                        fi
                    fi
                else
                    if jq -e ".${section} | has(\"${package_name}\")" "$file" >/dev/null 2>&1; then
                        # Get the version
                        local version=$(jq -r ".${section}[\"${package_name}\"]" "$file" 2>/dev/null)
                        
                        if [[ -n "$version" && "$version" != "null" ]]; then
                            file_found=true
                            log_info "    Found in $section: $version"
                            
                            # Check if version matches exactly or in acceptable range
                            if [[ "$version" == "$expected_version" ]] || 
                               [[ "$version" == "^$expected_version" ]] || 
                               [[ "$version" == "~$expected_version" ]] || 
                               [[ "$version" == ">=$expected_version" ]]; then
                                found=true
                                version_match=true
                                details="$details\n  EXACT VERSION MATCH in $(basename "$file") ($section: $version)"
                                log_info "    ✓ VERSION MATCH!"
                            else
                                found=true
                                details="$details\n  DIFFERENT VERSION in $(basename "$file") ($section: $version, expected: $expected_version)"
                                log_info "    ✗ Different version"
                            fi
                            break
                        fi
                    fi
                fi
            done
            
            if [[ "$file_found" == "false" ]]; then
                log_info "    Package not found in any dependency section"
            fi
            
            ((checked_files++))
            done
        fi
        
        # Check if actually used in code (only if not found in package.json)
        if [[ "$found" == "false" ]] && check_package_usage "$package_name"; then
            found=true
            details="$details\n  Found usage in source code (but not in package.json - possible transitive dependency)"
        elif [[ "$found" == "true" ]] && check_package_usage "$package_name"; then
            details="$details\n  Also confirmed usage in source code"
        fi
        
        if [[ "$found" == "true" ]]; then
            if [[ "$version_match" == "true" ]]; then
                FOUND_PACKAGES+=("$package_spec:$details:EXACT_VERSION")
                log_success "Package $package_name@$expected_version found (EXACT VERSION MATCH)"
            else
                FOUND_PACKAGES+=("$package_spec:$details:DIFFERENT_VERSION")
                log_warning "Package $package_name found but DIFFERENT VERSION than $expected_version"
            fi
        else
            NOT_FOUND_PACKAGES+=("$package_spec")
            log_info "Package $package_name@$expected_version not found"
        fi
    done
}

# Output results
output_results() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        # JSON output
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
    parse_args "$@"
    validate_repo
    
    # Check for required tools
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not installed. Please install jq first."
        exit 1
    fi
    
    log_info "Starting NPM package scan"
    log_info "Repository: $REPO_PATH"
    
    scan_packages
    output_results
    
    # Exit with appropriate code
    if [[ ${#FOUND_PACKAGES[@]} -gt 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
