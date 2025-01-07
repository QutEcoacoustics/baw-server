#!/bin/bash

# first arg expected to be ostype variable
# rest of args is command to run to pass on to rerun
if [[ $1 =~ .*homebrew ]]; then
    echo -e "\n== Running rerun with force polling ==\n"
    rerun --force-polling -- "${@:2}"
else
    rerun -- "${@:2}"
fi
