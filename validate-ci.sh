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

# Verify test file coverage
echo "📊 Test file distribution:"
echo "  API specs: $(find spec/api -name "*_spec.rb" | wc -l)"
echo "  Permission specs: $(find spec/permissions -name "*_spec.rb" 2>/dev/null | wc -l)"
echo "  Request specs: $(find spec/requests -name "*_spec.rb" 2>/dev/null | wc -l)"
echo "  Unit specs (inc. lib): $(find spec/unit spec/lib spec/support/matchers -name "*_spec.rb" 2>/dev/null | wc -l)"
echo "  Features+Capabilities: $(find spec/features spec/capabilities -name "*_spec.rb" 2>/dev/null | wc -l)"
echo "  Models+Controllers+etc: $(find spec/models spec/controllers spec/routing spec/views spec/migrations -name "*_spec.rb" 2>/dev/null | wc -l)"
echo "  Acceptance: $(find spec/acceptance -name "*_spec.rb" 2>/dev/null | wc -l)"

total_categorized=$(($(find spec/api -name "*_spec.rb" | wc -l) + $(find spec/permissions -name "*_spec.rb" 2>/dev/null | wc -l) + $(find spec/requests -name "*_spec.rb" 2>/dev/null | wc -l) + $(find spec/unit spec/lib spec/support/matchers -name "*_spec.rb" 2>/dev/null | wc -l) + $(find spec/features spec/capabilities -name "*_spec.rb" 2>/dev/null | wc -l) + $(find spec/models spec/controllers spec/routing spec/views spec/migrations -name "*_spec.rb" 2>/dev/null | wc -l) + $(find spec/acceptance -name "*_spec.rb" 2>/dev/null | wc -l)))
total_specs=$(find spec -name "*_spec.rb" | wc -l)

echo "  Total categorized: $total_categorized"
echo "  Total spec files: $total_specs"

if [ "$total_categorized" -eq "$total_specs" ]; then
    echo "✅ All test files are properly categorized!"
else
    echo "❌ Missing $(($total_specs - $total_categorized)) test files from categorization"
    echo "Uncategorized files:"
    # Find uncategorized files
    comm -23 <(find spec -name "*_spec.rb" | sort) <({ find spec/api -name "*_spec.rb"; find spec/permissions -name "*_spec.rb" 2>/dev/null; find spec/requests -name "*_spec.rb" 2>/dev/null; find spec/unit spec/lib spec/support/matchers -name "*_spec.rb" 2>/dev/null; find spec/features spec/capabilities -name "*_spec.rb" 2>/dev/null; find spec/models spec/controllers spec/routing spec/views spec/migrations -name "*_spec.rb" 2>/dev/null; find spec/acceptance -name "*_spec.rb" 2>/dev/null; } | sort)
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

echo
echo "🎉 CI configuration validation complete!"
echo
echo "📋 Summary of improvements:"
echo "  • Updated all GitHub Actions to latest versions"
echo "  • Created CI override file for Docker Compose without bind mounts"
echo "  • Implemented artifact-based container builds"
echo "  • Split tests into 7 parallel groups for faster execution"
echo "  • Eliminated permission issues with volume-based storage"
echo "  • Added proper caching and modern container registry usage"