#!/bin/bash
set -x

apt update
apt dist-upgrade -y
apt install kitty-terminfo

curl -sfL https://get.k3s.io | K3S_URL=https://master.private.main.oraclevcn.com:6443 K3S_CLUSTER_SECRET='${cluster_token}' sh -
