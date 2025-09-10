#!/bin/bash

# Simple test to check jq functionality
echo "Testing jq functionality..."

file="test-repo/subproject/package.json"
package_name="ansi-styles"
section="dependencies"

echo "File: $file"
echo "Package: $package_name"
echo "Section: $section"

echo "Testing jq command:"
jq_cmd="jq -e \".${section} | has(\\\"${package_name}\\\")\" \"$file\""
echo "Command: $jq_cmd"

if jq_result=$(jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
    echo "SUCCESS: $jq_result"
else
    echo "FAILED: $jq_result"
    echo "Exit code: $?"
fi

echo "Testing with timeout:"
if jq_result=$(timeout 5 jq -e ".${section} | has(\"${package_name}\")" "$file" 2>&1); then
    echo "SUCCESS with timeout: $jq_result"
else
    echo "FAILED with timeout: $jq_result"
    echo "Exit code: $?"
fi
