#!/usr/bin/env ruby

# Generate a dynamic test matrix by dividing spec files into equal buckets
require 'json'

# Get all spec files
spec_files = Dir.glob('spec/**/*_spec.rb').sort

# Default number of buckets
num_buckets = ENV.fetch('TEST_BUCKETS', '7').to_i

# Calculate files per bucket
files_per_bucket = (spec_files.length.to_f / num_buckets).ceil

# Create buckets by slicing the files
buckets = spec_files.each_slice(files_per_bucket).with_index.map do |bucket_files, index|
  {
    bucket: index + 1,
    files: bucket_files
  }
end

# Output for GitHub Actions matrix
matrix = {
  include: buckets.map { |bucket| { bucket: bucket[:bucket] } }
}

# Write bucket files to separate files for docker cp
buckets.each do |bucket|
  File.write("test-bucket-#{bucket[:bucket]}.txt", bucket[:files].join("\n") + "\n")
end

# Only output JSON to stdout for GitHub Actions
puts JSON.pretty_generate(matrix)

# Write summary to stderr so it doesn't interfere with JSON parsing
$stderr.puts "# Generated #{buckets.length} buckets with #{spec_files.length} total spec files"
buckets.each do |bucket|
  $stderr.puts "# Bucket #{bucket[:bucket]}: #{bucket[:files].length} files"
end