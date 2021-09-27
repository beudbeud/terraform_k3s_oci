#!/bin/bash
set -x

apt update
apt dist-upgrade -y
apt install -y mariadb-server kitty-terminfo 

sed -i 's/127.0.0.1/0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb.service

cat > mysql_secure_installation.sql << EOF
UPDATE mysql.user SET Password=PASSWORD('root-${password}') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
GRANT ALL ON *.* to k3s@'master.private.main.oraclevcn.com' IDENTIFIED BY '${password}';
FLUSH PRIVILEGES;
EOF

mysql -uroot < mysql_secure_installation.sql
rm mysql_secure_installation.sql

iptables -I INPUT -p tcp --dport 3306 -j ACCEPT
netfilter-persistent save
