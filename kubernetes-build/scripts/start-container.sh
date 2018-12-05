#!/usr/bin/env bash

if docker ps | grep kubernetes-build; then
    exit 0
fi

docker run --rm --name kubernetes-build -d -w $GOPATH/src/k8s.io/kubernetes -v $GOPATH/src/k8s.io/kubernetes:$GOPATH/src/k8s.io/kubernetes -v $HOME/.cache/bazel:$HOME/.cache/bazel -it kubernetes-build:latest sh &> /dev/null
# We don't want group name to match typical setups (e.g. `users`); otherwise group won't be created
docker exec -it $(docker ps --filter=name=kubernetes-build -q) groupadd -f -g $(id -g) kubernetes-build &> /dev/null
# Bazel uses the username to cache at the home dir ($HOME/.cache/bazel/_bazel_$USERNAME); keep it
docker exec -it $(docker ps --filter=name=kubernetes-build -q) useradd -NM -d $HOME -u $(id -u) -g $(id -g) $(id -u -n) &> /dev/null
