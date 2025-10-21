#!/bin/bash

docker build \
--no-cache \
-t fransking/vyos-l2tpclient .
docker image inspect fransking/vyos-l2tpclient --format='{{.Size}}'
