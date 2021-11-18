#!/usr/bin/env bash

#RAILS_ENV=test rails rswag
#
#
# Note: the above is currently failing due to a [bug](https://github.com/rswag/rswag/pull/274/files).
# Use this command in the interim:
#

# generate consistent documentation
RAILS_ENV=test rspec --pattern spec/api/{,**/}*_spec.rb --format Rswag::Specs::SwaggerFormatter --order defined --seed 48111
