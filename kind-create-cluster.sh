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
kind create cluster $OPTS "$@" && podman stop --all
