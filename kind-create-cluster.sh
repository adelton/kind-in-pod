#!/bin/bash

set -e

OPTS=
if [ -n "$KIND_CLUSTER_CONFIG" -a -s "$KIND_CLUSTER_CONFIG" ] ; then
	( set -x ; cp $KIND_CLUSTER_CONFIG /var/lib/containers/kind-cluster.yaml )
	OPTS="--config /var/lib/containers/kind-cluster.yaml"
fi

if podman ps -a --noheading | grep -q . ; then
	set -x
	podman ps -a
	exit
fi

set -x
( set +e ; while true ; do podman ps -a ; podman network ls ; sleep 3 ; done ) &
kind create cluster -v=10 $OPTS "$@" && podman stop --all
