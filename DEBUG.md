# VS Code デバッグ環境構築ガイド

このドキュメントでは、VS Code上でManaTEEプロジェクトをステップ実行するためのデバッグ環境の構築方法を説明します。

## 目次

1. [前提条件](#前提条件)
2. [必要な拡張機能のインストール](#必要な拡張機能のインストール)
3. [デバッグ環境のセットアップ](#デバッグ環境のセットアップ)
4. [デバッグ実行方法](#デバッグ実行方法)
5. [トラブルシューティング](#トラブルシューティング)

---

## 前提条件

### 1. ローカル環境が起動済みであること

Minikube環境が構築されている必要があります。

```bash
# Minikube環境のセットアップ
bash SETUP_MINIKUBE.sh
```

詳細は [SETUP_MINIKUBE.md](./SETUP_MINIKUBE.md) を参照してください。

### 2. 必要なツールのインストール

#### Go言語のインストール（未インストールの場合）

Goがインストールされていない場合は、まずGoをインストールしてください。

**推奨方法: 公式バイナリからのインストール（最新版）**

```bash
# 最新版のGoをダウンロード（1.23.8以上推奨）
wget https://go.dev/dl/go1.23.8.linux-amd64.tar.gz

# 既存のGoを削除（存在する場合）
sudo rm -rf /usr/local/go

# 新しいGoを展開
sudo tar -C /usr/local -xzf go1.23.8.linux-amd64.tar.gz

# 環境変数を設定
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# インストール確認
go version
```

**代替方法: パッケージマネージャからのインストール（簡単だが古いバージョン）**

```bash
# Ubuntu/Debianの場合
sudo apt update
sudo apt install golang-go

# または snap経由（より新しいバージョン）
sudo snap install go --classic

# 環境変数を設定
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# インストール確認
go version
```

> ⚠️ **注意**: このプロジェクトは Go 1.23.8+ を要求しています。`apt`でインストールされるバージョンは古い場合があるため、公式バイナリからのインストールを推奨します。

#### Go言語のデバッガ (Delve)

Goがインストールされた後、Delveをインストールしてください。

```bash
go install github.com/go-delve/delve/cmd/dlv@latest

# PATHが通っているか確認
dlv version
```

#### Python と pip のインストール（未インストールの場合）

Pythonやpipがインストールされていない場合は、まずインストールしてください。

```bash
# Pythonとpipがインストールされているか確認
python3 --version
pip3 --version

# インストールされていない場合
sudo apt update
sudo apt install python3 python3-pip python3-venv -y

# エイリアスを設定（オプション）
echo 'alias python=python3' >> ~/.bashrc
echo 'alias pip=pip3' >> ~/.bashrc
source ~/.bashrc

# 確認
python3 --version
pip3 --version
```

> **注意**: Ubuntu 22.04以降では、システムのPythonを保護するため、`pip install`は仮想環境内での使用が推奨されています。ただし、`debugpy`は開発ツールなので`--break-system-packages`フラグを使用するか、後述の方法でインストールできます。

#### Python デバッガ (debugpy)

```bash
# 方法1: pip3で直接インストール（Ubuntu 22.04以降で推奨）
pip3 install debugpy --break-system-packages

# 方法2: apt経由でインストール（より安全）
sudo apt install python3-debugpy

# 方法3: ユーザーディレクトリにインストール
pip3 install --user debugpy

# インストール確認
python3 -c "import debugpy; print(debugpy.__version__)"
```

---

## 必要な拡張機能のインストール

VS Codeで以下の拡張機能をインストールしてください。プロジェクトを開くと、推奨拡張機能として自動的に表示されます。

### Go言語開発

- **Go** (`golang.go`)
  - Go言語のサポート、デバッグ機能を提供

### Python開発

- **Python** (`ms-python.python`)
  - Python言語のサポート
- **Python Debugger** (`ms-python.debugpy`)
  - Pythonデバッグ機能

### その他の推奨拡張機能

- **Bazel** (`bazelbuild.vscode-bazel`) - Bazelビルドシステムのサポート
- **Kubernetes** (`ms-kubernetes-tools.vscode-kubernetes-tools`) - K8sリソース管理
- **Docker** (`ms-azuretools.vscode-docker`) - コンテナ管理
- **YAML** (`redhat.vscode-yaml`) - YAML編集サポート

### インストール方法

1. VS Codeのコマンドパレット (`Ctrl+Shift+P` / `Cmd+Shift+P`) を開く
2. `Extensions: Show Recommended Extensions` を選択
3. 表示された拡張機能をインストール

または、ターミナルから一括インストール:

```bash
code --install-extension golang.go
code --install-extension ms-python.python
code --install-extension ms-python.debugpy
code --install-extension bazelbuild.vscode-bazel
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
```

---

## デバッグ環境のセットアップ

### 1. VS Code設定ファイルの確認

プロジェクトには以下の設定ファイルが用意されています：

```
.vscode/
├── launch.json      # デバッグ構成
├── tasks.json       # タスク定義（ポートフォワード等）
├── settings.json    # エディタ設定
└── extensions.json  # 推奨拡張機能
```

### 2. Minikubeへのポートフォワード

デバッグ実行時、Minikube上のMySQLとMinIOに接続する必要があります。
`launch.json`で自動的にポートフォワードタスクが起動しますが、手動で実行することも可能です。

```bash
# MySQLへのポートフォワード (3306)
kubectl port-forward -n manatee svc/mysql 3306:3306 &

# MinIOへのポートフォワード (9000)
kubectl port-forward -n manatee svc/minio 9000:9000 &
```

### 3. 環境変数の設定

デバッグ構成には以下の環境変数が設定されています（`launch.json`内）：

#### API Server / Reconciler

```env
MYSQL_USERNAME=root
MYSQL_PASSWORD=password
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DATABASE=manatee
GCS_BUCKET=manatee-data
GCS_ENDPOINT=localhost:9000
GCS_USE_SSL=false
GCS_ACCESS_KEY=minioadmin
GCS_SECRET_KEY=minioadmin
```

必要に応じて `.vscode/launch.json` を編集してください。

---

## デバッグ実行方法

### 1. API Serverのデバッグ

#### ステップ実行の開始

1. `app/api/main.go` または任意のファイルを開く
2. ブレークポイントを設定（行番号の左をクリック）
3. VS Codeのデバッグビュー (`Ctrl+Shift+D` / `Cmd+Shift+D`) を開く
4. **"Debug API Server"** を選択
5. F5キーまたは緑の▶ボタンを押して実行

#### 動作確認

別のターミナルでAPIリクエストを送信してブレークポイントで停止することを確認：

```bash
# ヘルスチェック
curl http://localhost:8080/health

# ジョブ作成
curl -X POST http://localhost:8080/api/v1/job \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-job",
    "creator": "test-user",
    "data_sources": [...]
  }'
```

### 2. Reconcilerのデバッグ

#### ステップ実行の開始

1. `app/reconciler/main.go` または任意のファイルを開く
2. ブレークポイントを設定
3. デバッグビューで **"Debug Reconciler"** を選択
4. F5キーで実行

Reconcilerは10秒ごとにジョブの状態をポーリングします。ブレークポイントを設定した箇所で処理が停止します。

### 3. API Server + Reconciler の同時デバッグ

複数のコンポーネントを同時にデバッグできます：

1. デバッグビューで **"Debug API + Reconciler"** (Compound構成) を選択
2. F5キーで実行

両方のデバッガが同時に起動し、それぞれ独立してステップ実行できます。

### 4. Executor (Attestation) のデバッグ

```bash
1. `app/executor/attestation/main.go` を開く
2. ブレークポイントを設定
3. デバッグビューで **"Debug Executor Attestation"** を選択
4. F5キーで実行
```

### 5. テストのデバッグ

#### 特定のテストをデバッグ

1. テストファイル（例: `app/reconciler/reconciler_test.go`）を開く
2. テスト関数名を選択
3. デバッグビューで **"Debug Current Test (Go)"** を選択
4. F5キーで実行

または、テスト関数の上に表示される `debug test` リンクをクリック。

### 6. Pythonスクリプトのデバッグ

JupyterLab拡張機能やPythonスクリプトをデバッグする場合：

1. Pythonファイル（例: `app/jupyterlab_manatee/jupyterlab_manatee/handlers.py`）を開く
2. ブレークポイントを設定
3. デバッグビューで **"Debug Python Script"** を選択
4. F5キーで実行

---

## デバッグ機能の活用

### ブレークポイント

- **通常のブレークポイント**: 行番号の左をクリック
- **条件付きブレークポイント**: 右クリック → "Add Conditional Breakpoint"
  ```
  例: job.Status == "PENDING"
  ```
- **ログポイント**: ブレークせずにログ出力のみ
  ```
  例: Job ID: {job.ID}, Status: {job.Status}
  ```

### 変数の監視

デバッグ中に左側の「VARIABLES」パネルで変数の値を確認できます。
「WATCH」パネルで特定の式を監視することも可能：

```
例: 
- job.Status
- len(jobs)
- time.Now()
```

### ステップ実行のショートカット

- **F5**: 続行 (Continue)
- **F10**: ステップオーバー (Step Over) - 次の行へ
- **F11**: ステップイン (Step Into) - 関数の中に入る
- **Shift+F11**: ステップアウト (Step Out) - 関数から抜ける
- **Ctrl+Shift+F5**: 再起動 (Restart)
- **Shift+F5**: 停止 (Stop)

### デバッグコンソール

デバッグ中に「DEBUG CONSOLE」で任意のコードを実行できます：

```go
// Go
p job.ID
p job.Status
p fmt.Sprintf("Job: %+v", job)
```

```python
# Python
print(job_id)
len(data)
```

---

## リモートデバッグ (上級者向け)

Kubernetes上で動作しているコンテナに対してリモートデバッグを行うことも可能です。

### 1. Delveサーバー付きイメージのビルド

通常のイメージにDelveを追加する必要があります（本番環境では非推奨）。

### 2. Deployment の修正

```yaml
# デバッグ用のコマンドに変更
command: ["/dlv"]
args:
  - "exec"
  - "/app/api"
  - "--headless"
  - "--listen=:2345"
  - "--api-version=2"
  - "--accept-multiclient"
```

### 3. ポートフォワード

```bash
kubectl port-forward -n manatee deployment/api-server 2345:2345
```

### 4. VS Codeでアタッチ

デバッグビューで **"Attach to API Server (Remote)"** を選択して実行。

---

## トラブルシューティング

### 1. `go` コマンドが見つからない

**症状**: `Command 'go' not found`

**解決方法**:

Goがインストールされていません。[前提条件セクション](#go言語のインストール未インストールの場合)を参照してGoをインストールしてください。

**クイックインストール（公式バイナリ - 推奨）**:

```bash
# Go 1.23.8をダウンロード・インストール
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

### 2. `dlv` が見つからない

**症状**: `exec: "dlv": executable file not found in $PATH`

**解決方法**:

```bash
# Delveをインストール
go install github.com/go-delve/delve/cmd/dlv@latest

# PATHの確認
echo $PATH | grep -q "$(go env GOPATH)/bin" || echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# 確認
dlv version
```

### 3. `pip` コマンドが見つからない

**症状**: `Command 'pip' not found` または `Command 'pip3' not found`

**解決方法**:

```bash
# Pythonとpipをインストール
sudo apt update
sudo apt install python3 python3-pip python3-venv -y

# debugpyをインストール（Ubuntu 22.04以降）
pip3 install debugpy --break-system-packages

# または apt経由
sudo apt install python3-debugpy

# 確認
python3 --version
pip3 --version
python3 -c "import debugpy; print(debugpy.__version__)"
```

### 4. MySQLに接続できない

**症状**: `Error 2003: Can't connect to MySQL server on 'localhost'`

**解決方法**:

```bash
# ポートフォワードが起動しているか確認
ps aux | grep "kubectl port-forward"

# 起動していなければ手動で実行
kubectl port-forward -n manatee svc/mysql 3306:3306 &

# Minikubeクラスタが動作しているか確認
kubectl get pods -n manatee
```

### 5. Go拡張機能のツールがインストールされていない

**症状**: "gopls" や "dlv" のインストールを求められる

**解決方法**:

1. VS Codeのコマンドパレット (`Ctrl+Shift+P`) を開く
2. `Go: Install/Update Tools` を実行
3. すべてのツールを選択してインストール

### 6. Bazelビルドとの競合

**症状**: デバッグ実行時に "package not found" エラー

**解決方法**:

Bazelは独自のワークスペースを使用するため、VS CodeのGo拡張機能と競合する場合があります。

```bash
# go.modを最新の状態に保つ
go mod tidy

# VS CodeのGo設定を確認
# .vscode/settings.json の "go.inferGopath": true が設定されているか確認
```

### 7. ブレークポイントが無視される

**症状**: ブレークポイントを設定しても停止しない

**解決方法**:

- コードが最適化されていないか確認（デバッグモードで実行）
- ブレークポイントの位置が実行されるコードパスにあるか確認
- デバッグコンソールでエラーメッセージを確認

### 8. ポートが既に使用されている

**症状**: `bind: address already in use`

**解決方法**:

```bash
# 使用中のポートを確認
lsof -i :8080  # API Server
lsof -i :3306  # MySQL
lsof -i :9000  # MinIO

# プロセスを終了
kill -9 <PID>

# または、すべてのport-forwardを終了
pkill -f "kubectl port-forward"
```

---

## ベストプラクティス

### 1. ログレベルの調整

デバッグ時は詳細なログを出力すると便利です：

```go
// app/api/biz/dal/db/init.go
Logger: logger.Default.LogMode(logger.Info),  // Info レベル
```

### 2. ホットリロード

コードを変更するたびにデバッガを再起動する必要があります。効率的な開発のため：

- 小さな変更を繰り返しテスト
- ユニットテストを活用（デバッグより高速）

### 3. テスト駆動デバッグ

複雑なロジックの場合、先にテストを書いてからデバッグすると効率的です：

```go
// app/reconciler/reconciler_test.go
func TestReconcile(t *testing.T) {
    // テストケースを書く
    // デバッグ実行で動作を確認
}
```

### 4. デバッグ用のダミーデータ作成

`tutorials/` ディレクトリのスクリプトを使用してテストデータを準備：

```bash
cd tutorials
bash run_tutorial_jp.sh
```

---

## 参考リンク

- [VS Code Go Debugging](https://github.com/golang/vscode-go/wiki/debugging)
- [Delve Documentation](https://github.com/go-delve/delve/tree/master/Documentation)
- [VS Code Python Debugging](https://code.visualstudio.com/docs/python/debugging)
- [Kubernetes Port Forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

---

## まとめ

このガイドに従うことで、VS Code上でManaTEEプロジェクトの各コンポーネントをステップ実行できるようになります。

### 基本的なワークフロー

1. **Minikube環境起動**: `bash SETUP_MINIKUBE.sh`
2. **VS Code起動**: `code .`
3. **拡張機能インストール**: Go, Python拡張機能
4. **デバッグ実行**: F5キーでデバッグ開始
5. **ブレークポイント設定**: 調査したい箇所で停止
6. **ステップ実行**: F10/F11でコードを追跡

問題が発生した場合は、[トラブルシューティング](#トラブルシューティング)セクションを参照してください。
