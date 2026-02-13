#!/bin/bash
set -e

### ================================
###  DNS: NSD + Unbound
### ================================
setup_dns() {
  echo "[+] Installing NSD"
  sudo apt update
  sudo apt install -y nsd

  echo "[+] Writing NSD config"
  sudo tee /etc/nsd/nsd.conf.d/home.com.conf >/dev/null <<'EOF'
server:
    ip-address: 127.0.0.1
    port: 5353
    do-ip4: yes
    hide-version: yes
    identity: "NSD Authoritative Server"
    zonesdir: "/etc/nsd"

zone:
    name: "home.com"
    zonefile: "home.com.zone"

zone:
    name: "100.168.192.in-addr.arpa"
    zonefile: "192.168.100.rev"
EOF

  echo "[+] Writing forward zone"
  sudo tee /etc/nsd/home.com.zone >/dev/null <<'EOF'
$ORIGIN home.com.
$TTL 86400
@ IN SOA ns1.home.com. admin.home.com. (
    2026020701 ; serial
    3600       ; refresh
    900        ; retry
    604800     ; expire
    86400      ; minimum
)

@   IN NS  ns1.home.com.
ns1 IN A   192.168.100.101

test01 IN A 192.168.100.101
EOF

  echo "[+] Writing reverse zone"
  sudo tee /etc/nsd/192.168.100.rev >/dev/null <<'EOF'
$ORIGIN 100.168.192.in-addr.arpa.
$TTL 86400
@ IN SOA ns1.home.com. admin.home.com. (
    2026020801 ; Serial
    3600       ; Refresh
    900        ; Retry
    604800     ; Expire
    86400      ; Minimum TTL
)

@ IN NS ns1.home.com.

101 IN PTR test01.home.com.
EOF

  echo "[+] Checking nsd.conf"
  sudo nsd-checkconf /etc/nsd/nsd.conf
  echo "[+] Restarting Unbound"
  sudo sleep 10
  sudo systemctl restart nsd

  echo "[+] Installing Unbound"
  sudo apt install -y unbound

  sudo tee /etc/unbound/unbound.conf.d/lab.conf >/dev/null <<'EOF'
server:
    interface: 127.0.0.1
    port: 53
    access-control: 127.0.0.0/8 allow
    do-not-query-localhost: no
    domain-insecure: "home.com."
    domain-insecure: "100.168.192.in-addr.arpa."
    unblock-lan-zones: yes
    insecure-lan-zones: yes

stub-zone:
    name: "home.com."
    stub-addr: 127.0.0.1@5353

stub-zone:
    name: "100.168.192.in-addr.arpa."
    stub-addr: 127.0.0.1@5353

forward-zone:
    name: "."
    forward-addr: 8.8.8.8
    forward-addr: 8.8.4.4
EOF

  sudo unbound-checkconf

  echo "[+] Disabling systemd-resolved"
  sudo systemctl stop systemd-resolved || true
  sudo systemctl disable systemd-resolved || true

  echo "[+] Restarting Unbound"
  sudo systemctl restart unbound

  echo "[+] Writing resolv.conf"
  sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver ::1
nameserver 127.0.0.1
options trust-ad
EOF

  echo "[+] Writing wsl.conf"
  sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[network]
generateResolvConf=false
[boot]
systemd=true
EOF

  echo "[+] DNS setup complete"
}

### ================================
###  Ansible + Docker + K3s
### ================================
setup_base() {
  echo "[+] Installing Ansible"
  sudo apt update
  sudo apt install -y ansible git make

  mkdir -p ~/ansible-study
  tee ~/ansible-study/hosts >/dev/null <<'EOF'
[lab_servers]
localhost ansible_connection=local
EOF

  echo "[+] Installing Docker"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker $USER

  echo "[+] Installing K3s"
  curl -sfL https://get.k3s.io | sh -
  sudo chmod 644 /etc/rancher/k3s/k3s.yaml

  echo "[+] Base setup complete"
}

### ================================
###  AWX Operator
### ================================
setup_awx() {
  echo "[+] Deploying AWX Operator"
  sudo rm -rf awx-operator && sudo git clone https://github.com/ansible/awx-operator.git
  cd awx-operator

  export RELEASE_TAG=$(curl -s https://api.github.com/repos/ansible/awx-operator/releases/latest | grep tag_name | cut -d '"' -f 4)
  sudo git checkout $RELEASE_TAG

  export NAMESPACE=awx
  sudo make deploy

  echo "[+] Creating AWX instance"
  tee awx-instance.yaml >/dev/null <<'EOF'
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-server
  namespace: awx
spec:
  service_type: nodeport
EOF

  kubectl apply -f awx-instance.yaml
  cd ..

  echo "[+] AWX deployment complete"
}

### ================================
###  NetBox (Helm)
### ================================
setup_netbox() {
  echo "[+] Installing Helm"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  echo "[+] Deploying NetBox via OCI"
  kubectl create namespace netbox || true
  # OCIリポジトリから直接インストール
  # 127.0.0.1:53 問題等で名前解決が不安な場合は、事前に疎通確認を推奨
  sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm install my-netbox \
    oci://ghcr.io/netbox-community/netbox-chart/netbox \
    --namespace netbox \
    --set service.type=NodePort \
    --set postgresql.auth.password=netboxpassword \
    --set redis.auth.password=netboxpassword \
    --set startupProbe.enabled=false \
    --set livenessProbe.enabled=false \
    --set readinessProbe.enabled=false \
    --set persistence.enabled=true

  echo "[+] NetBox deployment complete"
}

### ================================
###  Main Menu
### ================================
echo "Select setup step:"
echo "1) DNS (NSD + Unbound)"
echo "2) Base (Ansible + Docker + K3s)"
echo "3) AWX"
echo "4) NetBox"
echo "5) ALL"

read -p "Enter choice: " choice

case $choice in
  1) setup_dns ;;
  2) setup_base ;;
  3) setup_awx ;;
  4) setup_netbox ;;
  5) setup_dns; setup_base; setup_awx; setup_netbox ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

  echo "============================================================"
  echo "                SUCCESSFULLY COMPLETED                      "
  echo "============================================================"
  cat <<'EOF'

[ Next Steps ]
"watch kubectl get pods -A" でPodが  ** 0/1 Completed **, ** X/X Running **  になるのを確認してください。
全て立ち上がるには、Errorを繰り返しながら5~10分程度かかります。

[ Tips ]
- hostname -I | awk '{print $1}' で、WSLのIPアドレスを確認できます。
- ブラウザで http://<WSL_IP>:<NodePort> にアクセスして、AWXやNetBoxのUIにアクセスできます。

[ AWX ]
AWXのNodePortは以下で確認できます。(80:<NodePort>)
  kubectl -n awx get svc awx-server-service
初期adminユーザのパスワードは以下で確認できます。
  kubectl -n awx get secret awx-server-admin-password -o jsonpath='{.data.password}' | base64 --decode; echo

[ NetBox ]
NetBoxのNodePortは以下で確認できます。(80:<NodePort>)
  kubectl -n netbox get svc my-netbox
初期adminユーザのパスワードは以下で確認できます。
  kubectl get secret -n netbox my-netbox-superuser -o jsonpath="{.data.password}" | base64 --decode; echo

EOF
