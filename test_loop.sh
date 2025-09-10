#!/bin/bash

# Test the loop logic that's failing
set -euo pipefail

echo "Testing loop logic..."

package_files=("test-repo/subproject/package.json" "test-repo/package.json")
package_name="ansi-styles"
sections=("dependencies" "devDependencies" "peerDependencies" "optionalDependencies")

for file in "${package_files[@]}"; do
    echo "Checking file: $file"
    file_found=false
    
    for section in "${sections[@]}"; do
        echo "  Checking section: $section"
        
        # Test the jq command
        if jq_result=$(timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
            echo "    Package found in $section: $jq_result"
            if [[ "$jq_result" == "true" ]]; then
                file_found=true
                echo "    ✓ Package found!"
                break
            fi
        else
            echo "    Package not found in $section: $jq_result"
        fi
    done
    
    if [[ "$file_found" == "false" ]]; then
        echo "  Package not found in any section of this file"
    fi
    
    echo "Finished checking file: $file"
done

echo "Loop completed successfully!"
