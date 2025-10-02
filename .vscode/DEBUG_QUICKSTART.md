# VS Code デバッグ環境 - クイックスタート

このファイルは、デバッグ環境を素早く起動するための簡易ガイドです。
詳細は [DEBUG.md](./DEBUG.md) を参照してください。

## 🚀 セットアップ手順

### 0️⃣ 開発ツールのインストール（未インストールの場合）

#### Goのインストール

```bash
# Goがインストールされているか確認
go version

# インストールされていない場合は以下を実行（公式バイナリ - 推奨）
wget https://go.dev/dl/go1.23.8.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.23.8.linux-amd64.tar.gz

# 環境変数を設定
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# 確認
go version
```

#### Pythonとpipのインストール

```bash
# Pythonとpipがインストールされているか確認
python3 --version
pip3 --version

# インストールされていない場合
sudo apt update
sudo apt install python3 python3-pip python3-venv -y

# 確認
python3 --version
pip3 --version
```

### 1️⃣ Minikube環境を起動

```bash
bash SETUP_MINIKUBE.sh
```

### 2️⃣ VS Code拡張機能をインストール

VS Codeを開き、推奨拡張機能の通知から以下をインストール：
- **Go** (golang.go)
- **Python** (ms-python.python)
- **Python Debugger** (ms-python.debugpy)

または一括インストール：

```bash
code --install-extension golang.go
code --install-extension ms-python.python
code --install-extension ms-python.debugpy
```

### 3️⃣ デバッガのインストール

#### Go デバッガ (Delve)

```bash
go install github.com/go-delve/delve/cmd/dlv@latest

# 確認
dlv version
```

#### Python デバッガ (debugpy)

```bash
# Ubuntu 22.04以降
pip3 install debugpy --break-system-packages

# または apt経由
sudo apt install python3-debugpy

# 確認
python3 -c "import debugpy; print(debugpy.__version__)"
```

### 4️⃣ デバッグ構成を選択

VS Codeのデバッグビュー（`Ctrl+Shift+D` / `Cmd+Shift+D`）を開き、以下から選択：

- **Debug API Server** - API Serverをデバッグ
- **Debug Reconciler** - Reconcilerをデバッグ
- **Debug API + Reconciler** - 両方を同時にデバッグ
- **Debug Executor Attestation** - Executorをデバッグ

### 5️⃣ デバッグ開始

1. ブレークポイントを設定（行番号の左をクリック）
2. **F5キー**を押してデバッグ開始
3. ステップ実行（F10: 次の行、F11: 関数内に入る）

---

## 📍 ブレークポイント設定のおすすめ箇所

### API Server

- `app/api/main.go:16` - main関数の開始
- `app/api/biz/handler/job.go` - ジョブ作成/取得ハンドラ
- `app/api/biz/service/job_service.go` - ビジネスロジック

### Reconciler

- `app/reconciler/main.go:20` - Reconcileループ
- `app/reconciler/reconciler.go` - ジョブステート遷移ロジック

---

## 🧪 動作確認

デバッグ中に別ターミナルでAPIリクエストを送信：

```bash
# ヘルスチェック
curl http://localhost:8080/health

# ジョブ一覧取得
curl http://localhost:8080/api/v1/jobs
```

ブレークポイントで処理が停止すれば成功です！

---

## ⚠️ トラブルシューティング

### Goが見つからない

```bash
# Goがインストールされているか確認
go version

# インストールされていない場合は手順0️⃣を実行
```

### pipが見つからない

```bash
# Pythonとpipがインストールされているか確認
python3 --version
pip3 --version

# インストールされていない場合
sudo apt update
sudo apt install python3 python3-pip python3-venv -y

# debugpyをインストール
pip3 install debugpy --break-system-packages
```

### MySQL接続エラー

```bash
kubectl port-forward -n manatee svc/mysql 3306:3306 &
kubectl port-forward -n manatee svc/minio 9000:9000 &
```

### `dlv` が見つからない

```bash
# PATHを確認・設定
export PATH=$PATH:$(go env GOPATH)/bin
source ~/.bashrc

# Delveを再インストール
go install github.com/go-delve/delve/cmd/dlv@latest
dlv version
```

### ポート使用中エラー

```bash
pkill -f "kubectl port-forward"
```

---

## 📚 次のステップ

詳細なデバッグ機能の使い方は [DEBUG.md](./DEBUG.md) を参照してください：

- 条件付きブレークポイント
- ログポイント
- 変数の監視
- リモートデバッグ
- テストのデバッグ

Happy Debugging! 🎉
