#!/bin/bash
set -x

apt update
apt dist-upgrade -y
apt install -y kitty-terminfo

iptables -I INPUT -p tcp --dport 6443 -j ACCEPT
netfilter-persistent save

#curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--no-deploy traefik" K3S_CLUSTER_SECRET='${cluster_token}' sh -s - server --tls-san="k3s.local"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--no-deploy traefik" K3S_CLUSTER_SECRET='${cluster_token}' sh -s - server --tls-san="k3s.local" --datastore-endpoint="mysql://k3s:${password}@tcp(externaldb.private.main.oraclevcn.com:3306)/kubernetes"

while ! nc -z localhost 6443; do
  sleep 1
done

mkdir /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sed -i "s/127.0.0.1/$(curl -s ifconfig.co)/g" /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/opc/.kube/ -R
