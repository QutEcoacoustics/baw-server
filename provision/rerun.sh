#!/bin/bash

# first arg expected to be ostype variable
# rest of args is command to run to pass on to rerun
if [[ "$RERUN_FORCE_POLLING" = "true" ]]; then
    echo -e "\n== Running rerun with force polling!!! ==\n"
    rerun --force-polling -- "${@}"
else
    rerun -- "${@}"
fi
