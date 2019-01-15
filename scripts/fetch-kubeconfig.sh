#!/usr/bin/env bash

CLUSTER_NAME=$(ruby -I vagrant -r utils -e 'print cluster.name' 2> /dev/null)

if [ -f tmp/$CLUSTER_NAME/admin.conf ]; then
    mkdir -p ~/.kube
    cp tmp/$CLUSTER_NAME/admin.conf ~/.kube/config
    echo ">>> kubeconfig written to ${HOME}/.kube/config"
else
    echo ">>> kubeconfig not present yet. Run \`PROFILE=$PROFILE make kubeconfig\` when you have initialized the cluster"
fi
