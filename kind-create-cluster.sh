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

set +e
set -x
kind create cluster -v=10 $OPTS "$@" --retain
kind export logs /tmp/kind-logs
for i in /tmp/kind-logs/kind-control-plane/*.log ; do cat $i ; done
podman stop --all
