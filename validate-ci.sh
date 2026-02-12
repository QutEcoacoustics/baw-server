#!/bin/bash
# Validation script for CI configuration
# Run this script to verify the CI setup is correct

set -e

echo "🔍 Validating CI Configuration..."
echo

# Check if docker-compose.ci.yml is valid as an override
echo "✅ Validating docker-compose.ci.yml as override..."
docker compose -f docker-compose.yml -f docker-compose.ci.yml config --quiet
echo "✅ Docker Compose override file is valid"
echo

# Test the dynamic matrix generation
echo "🔬 Testing dynamic test matrix generation..."
ruby generate-test-matrix.rb > /tmp/matrix-test.json
buckets=$(ruby -e "require 'json'; puts JSON.parse(File.read('/tmp/matrix-test.json'))['include'].length")
total_specs=$(find spec -name "*_spec.rb" | wc -l)

echo "  Generated $buckets test buckets"
echo "  Total spec files: $total_specs"

# Verify all buckets have files
bucket_files=0
for i in $(seq 1 $buckets); do
  if [ -f "test-bucket-$i.txt" ]; then
    files_in_bucket=$(wc -l < "test-bucket-$i.txt")
    echo "  Bucket $i: $files_in_bucket files"
    bucket_files=$((bucket_files + files_in_bucket))
  else
    echo "❌ Missing test-bucket-$i.txt"
    exit 1
  fi
done

if [ "$bucket_files" -eq "$total_specs" ]; then
    echo "✅ All $total_specs test files are properly distributed across buckets!"
else
    echo "❌ Bucket distribution error: $bucket_files files in buckets vs $total_specs total files"
    exit 1
fi

echo

# Check GitHub Actions workflow syntax
echo "🔧 Validating GitHub Actions workflow..."
if command -v actionlint >/dev/null 2>&1; then
    actionlint .github/workflows/ci.yml
    echo "✅ GitHub Actions workflow is valid"
else
    echo "ℹ️  Install 'actionlint' for workflow validation"
fi

# Cleanup test files
rm -f test-bucket-*.txt /tmp/matrix-test.json

echo
echo "🎉 CI configuration validation complete!"
echo
echo "📋 Summary of improvements:"
echo "  • Updated all GitHub Actions to latest versions with cached LFS"
echo "  • Created CI override file with environment variable image reference"
echo "  • Implemented dynamic test matrix with even distribution"
echo "  • Simplified test execution with docker cp approach"
echo "  • Eliminated permission issues with volume-based storage"
echo "  • Added proper caching and modern container registry usage"