#!/bin/bash

str=$"\n"
nohup bash /run_jupyter.sh --no-browser --allow-root >/dev/null 2>&1 &
sstr=$(echo -e $str)
echo $sstr