#!/bin/bash

set -e

if podman ps -a --noheading | grep . ; then
	exit
fi

set -x
kind create cluster "$@"

