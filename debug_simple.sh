#!/bin/bash

# Simple debug script to test the problematic section
set -euo pipefail

echo "=== SIMPLE DEBUG TEST ==="
echo "Testing jq commands that are failing..."

file="test-repo/subproject/package.json"
package_name="ansi-styles"
section="dependencies"

echo "File: $file"
echo "Package: $package_name"
echo "Section: $section"

# Test 1: Basic jq command
echo "Test 1: Basic jq command"
jq_result=$(jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1)
echo "Result: $jq_result"
if [[ "$jq_result" == "true" ]]; then
    echo "✓ Package found"
elif [[ "$jq_result" == "false" ]]; then
    echo "✓ Package not found (correct behavior)"
else
    echo "✗ jq command failed: $jq_result"
fi

# Test 2: jq with timeout
echo "Test 2: jq with timeout"
if timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" >/dev/null 2>&1; then
    echo "✓ jq with timeout works"
else
    echo "✗ jq with timeout failed"
fi

# Test 3: jq with error capture
echo "Test 3: jq with error capture"
if jq_result=$(jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
    echo "✓ jq with error capture works: $jq_result"
else
    echo "✗ jq with error capture failed: $jq_result"
fi

# Test 4: jq with timeout and error capture
echo "Test 4: jq with timeout and error capture"
if jq_result=$(timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
    echo "✓ jq with timeout and error capture works: $jq_result"
else
    echo "✗ jq with timeout and error capture failed: $jq_result"
fi

echo "=== END DEBUG TEST ==="
