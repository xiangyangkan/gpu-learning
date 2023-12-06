#!/bin/bash

str=$"\n"
nohup bash /run_ssh.sh >/dev/null 2>&1 &
sstr=$(echo -e $str)
echo $sstr