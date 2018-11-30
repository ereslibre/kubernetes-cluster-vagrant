#!/usr/bin/env bash

set -euo pipefail

BASE_BOX=kubernetes-vagrant

if ! vagrant box list | grep $BASE_BOX &> /dev/null; then
    vagrant destroy -f
    vagrant up
    vagrant ssh -c 'cat /dev/null > ~/.bash_history && history -c && exit 0'
    rm -f $BASE_BOX.box
    vagrant package --output $BASE_BOX.box
    vagrant box add -f $BASE_BOX $BASE_BOX.box
    vagrant destroy -f
    rm $BASE_BOX.box
else
    echo ">>> Base box ($BASE_BOX) already exists, skipping build"
fi
