# my-first-lab
WSL 上に **DNS（NSD + Unbound）/ Ansible / Docker / K3s / AWX / NetBox** を自動構築するためのセットアップスクリプトです。

このスクリプトは、学習環境や検証環境を素早く立ち上げることを目的としています。

---

## 🚀 機能一覧

### 1. DNS（NSD + Unbound）
- NSD による Authoritative DNS の構築  
- Unbound による Recursive DNS の構築  
- 正引き / 逆引きゾーンの自動生成  
- systemd-resolved の無効化  
- resolv.conf の固定化（WSL 用）

### 2. Base（Ansible + Docker + K3s）
- Ansible / Git / Make のインストール  
- Docker の自動インストール  
- K3s（軽量 Kubernetes）のセットアップ  
- kubeconfig の権限調整

### 3. AWX Operator
- AWX Operator のクローン  
- 最新リリースタグの自動取得  
- AWX インスタンスのデプロイ  
- NodePort でのアクセス設定

### 4. NetBox（Helm）
- Helm のインストール  
- NetBox Chart（OCI）からのデプロイ  
- NodePort でのアクセス設定  
- PostgreSQL / Redis のパスワード設定

---

## 🛠 使い方

### 1. リポジトリをクローン

```bash
git clone https://github.com/<yourname>/<repo>.git
cd <repo>
```

### 2. 実行権限を付与

```bash
chmod +x setup.sh
```

### 3. セットアップ開始

```bash
./setup.sh
```

メニューが表示されるので、実行したい項目を選択してください。

---

## 🌐 アクセス方法

### AWX
NodePort の確認:

```bash
kubectl -n awx get svc awx-server-service
```

初期 admin パスワード:

```bash
kubectl -n awx get secret awx-server-admin-password -o jsonpath='{.data.password}' | base64 --decode; echo
```

### NetBox
NodePort の確認:

```bash
kubectl -n netbox get svc my-netbox
```

初期 admin パスワード:

```bash
kubectl get secret -n netbox my-netbox-superuser -o jsonpath="{.data.password}" | base64 --decode; echo
```

---

## 📝 注意事項
- WSL の IP は `hostname -I | awk '{print $1}'` で確認できます  
- DNS を変更するため、WSL のネットワーク再起動が必要な場合があります  
- AWX / NetBox は起動に 5〜10 分かかることがあります  

---
