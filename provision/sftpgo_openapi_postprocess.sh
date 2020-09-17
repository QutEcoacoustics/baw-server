#!/usr/bin/env sh

# fix bug in api generation. The '*' enum for the Permissions model produces a
# zero length identifier after sanitization.
sed -i -r 's/^(\s+)( = "\*".*)/\1ALL\2/' "$1"
