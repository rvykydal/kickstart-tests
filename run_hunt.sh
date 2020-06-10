#!/bin/bash

for i in {1..100}
  do
    echo "Running batch number $i"
    if [[ -e ./stop ]]; then
      exit 0
    fi
    ./run.sh
  done

