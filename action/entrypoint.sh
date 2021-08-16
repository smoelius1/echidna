#! /bin/bash

set -eu

export PYTHONPATH=/root/.local/lib/python3.6/site-packages

OPTIONS="contract config"

CMD=(echidna-test "$INPUT_FILES")

for OPTION in OPTIONS; do
    VAR="INPUT_${OPTION^^}"
    echo "$VAR"
    CMD+=(--$OPTION ${!VAR})
done

echo "${CMD[@]}"

"${CMD[@]}"
