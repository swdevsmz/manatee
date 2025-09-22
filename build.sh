#!/bin/bash
set -e

# WSL2 Ubuntu 24.04 用 ManaTEE Minikube 環境構築スクリプト
# 実行前に: minikube, docker, bazelisk, socat, kubectl がインストールされていることを確認してください

###############################################################
# 0. 必要なコマンドがなければ自動インストール

# bazelisk
if ! command -v bazelisk &> /dev/null; then
	echo "[INFO] bazeliskが見つかりません。インストールを開始します..."
	curl -LO https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
	sudo install bazelisk-linux-amd64 /usr/local/bin/bazelisk
	rm bazelisk-linux-amd64
	echo "[INFO] bazeliskをインストールしました。"
fi
# Docker
if ! command -v docker &> /dev/null; then
	echo "[INFO] Dockerが見つかりません。インストールを開始します..."
	sudo apt-get update
	sudo apt-get install -y ca-certificates curl gnupg lsb-release
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) stable" | \
		sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	sudo systemctl enable docker
	sudo systemctl start docker
	sudo usermod -aG docker $USER
	echo "[INFO] Dockerをインストールし、dockerグループに$USERを追加しました。"
	echo "[INFO] このまま続行しますが、dockerコマンド利用には再ログインが必要な場合があります。"
fi

# minikube
if ! command -v minikube &> /dev/null; then
	echo "[INFO] minikubeが見つかりません。インストールを開始します..."
	curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
	sudo install minikube-linux-amd64 /usr/local/bin/minikube
	rm minikube-linux-amd64
	echo "[INFO] minikubeをインストールしました。"
fi

# kubectl
if ! command -v kubectl &> /dev/null; then
	echo "[INFO] kubectlが見つかりません。インストールを開始します..."
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	rm kubectl
	echo "[INFO] kubectlをインストールしました。"
fi

# mc (MinIO Client)
if ! command -v mc &> /dev/null; then
    echo "[INFO] mc (MinIO Client)が見つかりません。インストールを開始します..."
    curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
    sudo install mc /usr/local/bin/mc
    rm mc
    echo "[INFO] mcをインストールしました。"
fi

# Terraform
if ! command -v terraform &> /dev/null; then
    echo "[INFO] Terraformが見つかりません。インストールを開始します..."
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update
    sudo apt-get install -y terraform
    echo "[INFO] Terraformをインストールしました。"
fi

# build-essential (for gcc, etc.)
if ! command -v gcc &> /dev/null; then
    echo "[INFO] GCCが見つかりません。build-essentialをインストールします..."
    sudo apt-get update
    sudo apt-get install -y build-essential
    echo "[INFO] build-essentialをインストールしました。"
fi

# 0.5. 既存のMinikube環境をクリーンアップ
echo "[INFO] 既存のMinikubeクラスタを削除して、クリーンな状態から開始します..."
if minikube status &> /dev/null; then
    minikube delete
    echo "[INFO] 既存クラスタの削除が完了しました。"
else
    echo "[INFO] 既存のMinikubeクラスタは見つかりませんでした。スキップします。"
fi


# 1. Minikubeクラスタ起動
minikube start --memory=12192mb --cpus=8 --disk-size=50g --insecure-registry "10.0.0.0/24"

# 2. Minikube用リソース適用
pushd resources/minikube
./apply.sh
popd

# 3. MinikubeのDocker環境設定
eval $(minikube docker-env)

# 4. Bazelでイメージビルド＆ロード
if [ ! -f env.bzl ]; then
    echo "env.blz。Bazelビルドを開始します。"
    cp .env.example env.bzl
fi



bazelisk run //:load_all_images

# 5. Minikubeレジストリアドオン有効化
minikube addons enable registry

###############################################################
# 6. socatプロキシ起動（バックグラウンド）
# [socatとは?]
# socatは「SOcket CAT」の略で、ネットワークソケット間のデータ転送を行うツールです。
# このスクリプトでは、ローカルホストの5000番ポートとminikubeクラスタ内の5000番ポート（レジストリ）を中継するために使用します。
# これにより、ローカルのdocker pushコマンドでminikube内のレジストリにイメージを転送できるようになります。
###############################################################
MINIKUBE_IP=$(minikube ip)
nohup docker run --rm --network=host alpine ash -c "apk add socat && socat TCP-LISTEN:5000,reuseaddr,fork TCP:${MINIKUBE_IP}:5000" > socat.log 2>&1 &
SOCAT_PID=$!
sleep 5

# 7. executorイメージのタグ付け＆プッシュ
docker tag executor localhost:5000/executor
docker push localhost:5000/executor

# socatプロキシ停止
kill $SOCAT_PID

# 8. Minikube用デプロイメント適用
pushd deployment/minikube
./deploy.sh
popd


echo "\n[INFO] ManaTEE Minikube環境構築が完了しました。"
echo "JupyterHubへは: kubectl --namespace=manatee port-forward service/proxy-public 8080:http でアクセスできます。"
echo "http://localhost:8080 をブラウザで開いてください。"

#cd tutorials && bash ./run_tutorial_jp.sh