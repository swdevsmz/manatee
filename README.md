# ManaTEE on Minikube (ローカル開発環境)

このドキュメントは、Minikubeを使用してローカルPC上にManaTEEのテスト環境を構築し、チュートリアルを実行する手順について説明します。オリジナルのREADMEは `README.original.md` にリネームされています。

## 概要

開発とテストを容易にするため、GCP環境を必要としないMinikubeベースのセットアップが用意されています。`build.sh` スクリプトは、必要なツールのインストールからManateeのデプロイまで、環境構築の全プロセスを自動化します。

**注意:** この環境は実際のTEE（Trusted Execution Environment）を使用しないため、セキュリティ機能の検証ではなく、アプリケーションの動作確認や開発を目的としています。

## 技術スタック要件

ManaTEEプロジェクトを実行するために必要な技術スタックは以下の通りです：

### コンテナ・オーケストレーション
- **Docker** - コンテナイメージのビルド・実行に使用
- **Kubernetes** - ManaTEEのマイクロサービス（API、Reconciler、Executor）をオーケストレーション
- **Minikube** - ローカル開発・テスト用のKubernetesクラスタ
- **Helm** - Kubernetesアプリケーションのパッケージ管理とデプロイメント

### ビルドツール・言語
- **Bazel/Bazelisk** - ManaTEEのビルドシステム（Go、TypeScript、Pythonの統合ビルド）
- **Go 1.23.8+** - バックエンドAPI、Reconciler、Executorの実装言語
- **Node.js/npm** - JupyterLab拡張のフロントエンド開発
- **Python 3.8+** - JupyterLab拡張のバックエンド、データ分析環境

### データベース・ストレージ
- **MySQL 8.0** - ジョブ状態管理・メタデータストレージ
- **MinIO** - S3互換オブジェクトストレージ（データファイル・成果物保存）

### Jupyter環境
- **JupyterLab 4.0+** - データ分析・ノートブック実行環境
- **JupyterHub** - マルチユーザーJupyter環境の管理

### セキュリティ・認証
- **Google Cloud Platform (GCP)** - 本番環境でのTEE（Confidential Computing）
- **Custom Attestation Token** - TEE環境での検証・認証メカニズム

### 開発・運用ツール
- **kubectl** - Kubernetesクラスタ管理
- **socat** - ネットワークプロキシ（Minikube レジストリアクセス用）
- **mc (MinIO Client)** - オブジェクトストレージ操作

### クラウドサービス（本番環境）
- **Google Cloud Storage** - データファイル・成果物の永続化
- **Google Compute Engine** - Confidential Space（TEE）での計算実行
- **Google Cloud SQL** - 本番環境でのマネージドMySQL

各技術の役割は、Data Clean Roomでのセキュアなデータ処理、マイクロサービスアーキテクチャ、スケーラブルなクラウドインフラを実現するためです。

## コンテナ構成

ManaTEEは以下の4つの主要コンテナで構成されています：

### 1. API Server (`api:latest`)
- **ベースイメージ**: `@distroless_base_linux_amd64` (軽量なLinuxディストリビューション)
- **実行プロセス**: Go製HTTPサーバー (Hertz フレームワーク)
- **ポート**: 8080
- **役割**: 
  - JupyterLab拡張からのリクエストを受信
  - ジョブの作成・管理・状態確認のREST API提供
  - MySQLでのジョブメタデータ管理
  - MinIOでのファイルアップロード・ダウンロード用署名URL発行

### 2. Reconciler (`reconciler:latest`)
- **ベースイメージ**: `@distroless_base_linux_amd64`
- **実行プロセス**: Go製バックグラウンドプロセス (10秒間隔で実行)
- **役割**:
  - ジョブ状態の監視・調整
  - Kanikoを使ったDockerイメージビルド管理
  - TEEバックエンド（GCP Confidential Space / Mock）での計算実行管理
  - ジョブライフサイクルの完全管理

### 3. Executor (`executor:latest`)
- **ベースイメージ**: `@scipy-notebook_linux_amd64` (JupyterLab + Python科学計算環境)
- **実行プロセス**: Python Jupyter環境 + カスタム認証ツール
- **含まれるツール**:
  - `gen_custom_token`: TEE環境での認証トークン生成バイナリ
  - Jupyter Notebook実行環境
  - NumPy, SciPy, Pandas等の科学計算ライブラリ
- **役割**:
  - セキュアな計算環境でのデータ分析実行
  - TEE認証トークンの生成・検証
  - 分析結果の暗号化・署名

### 4. JupyterLab Extension (`jupyterlab_manatee:latest`)
- **ベースイメージ**: `@scipy-notebook_linux_amd64`
- **含まれるコンポーネント**:
  - JupyterLab拡張パッケージ (.whl)
  - Node.js環境 (フロントエンド TypeScript/React)
  - Python拡張サーバー (aiohttp, tornado)
  - カスタムフック (`20custom-hook.sh`)
- **役割**:
  - JupyterLabのサイドバーUI提供
  - Data Clean Roomジョブの投入・監視
  - データソースの管理
  - 分析結果の取得・表示

### 補助コンテナ
- **MySQL 8.0**: ジョブメタデータ・状態管理
- **MinIO**: オブジェクトストレージ（S3互換）
- **Cloud SQL Proxy**: 本番環境でのGoogle Cloud SQL接続

## Kubernetes依存性について

**ManaTEEは現在Kubernetes環境が必須です**。以下の理由により、Docker Composeでの代替は困難です：

### Kubernetes固有の機能依存
1. **Kaniko Image Builder**: 
   - KubernetesのJob APIを使用してDockerイメージをビルド
   - `k8s.io/client-go/kubernetes`ライブラリでJob作成・監視・削除
   
2. **Mock TEE Backend**:
   - KubernetesのBatch Job APIで計算処理を実行
   - Pod内のサービスアカウント・ネームスペース情報を取得
   
3. **InCluster Configuration**:
   - `rest.InClusterConfig()`でKubernetesクラスタ内認証
   - `/var/run/secrets/kubernetes.io/serviceaccount/`のサービスアカウント情報に依存

### Docker Compose代替の課題
- **Job管理**: KubernetesのJob APIに代わる仕組みが必要
- **動的コンテナ生成**: 分析ジョブごとに新しいコンテナを作成する機能
- **リソース管理**: CPU・メモリ制限、タイムアウト処理
- **ネットワーク分離**: セキュアな計算環境の実現

### 代替案
Docker Composeで動作させるには、以下の改修が必要です：
1. **Image Builder抽象化**: Docker APIを使ったビルダー実装
2. **Job Runner改修**: Docker APIでのコンテナ実行・監視
3. **認証メカニズム変更**: Kubernetes依存の認証を汎用化
4. **設定外部化**: InCluster設定の代替手段

現状では、**Minikube（ローカルKubernetes）が最も簡単な開発環境**です。

## AWS上でのデプロイ構成（TEE環境含む）

ManaTEEをAWS上でTEE環境を含めて運用する場合の推奨構成は以下の通りです。

### AWSサービス構成

#### 1. コンテナオーケストレーション
- **Amazon EKS (Elastic Kubernetes Service)**
  - ManaTEEのKubernetes依存を満たすマネージドKubernetesサービス
  - API Server, Reconciler, JupyterHub/JupyterLabをデプロイ
  - Auto Scaling、セキュリティグループ、IAMロール統合

#### 2. TEE環境
- **AWS Nitro Enclaves**
  - EC2インスタンス内で動作する隔離された計算環境
  - データ分析ジョブをセキュアに実行
  - Attestation（認証）機能でワークロードの整合性検証
  - **対応インスタンスタイプ**: M5, M5n, C5, C5n, R5, R5n等（`.metal`でない通常インスタンス）

#### 3. データベース・ストレージ
- **Amazon RDS for MySQL**: ジョブメタデータ・状態管理
- **Amazon S3**: データファイル・分析結果の保存（MinIOの代替）
- **Amazon ECR (Elastic Container Registry)**: Dockerイメージ保管

#### 4. ネットワーク・セキュリティ
- **Amazon VPC**: プライベートネットワーク分離
- **AWS PrivateLink**: EKSとNitro Enclaves間の安全な通信
- **AWS KMS**: 暗号化キー管理

### アーキテクチャ変更点

現在のManaTEEはGCP Confidential Space向けに実装されているため、AWS対応には以下の改修が必要です：

#### 1. TEE Backend実装の追加
```go
// 新規実装が必要
type TEEProviderAWSNitroEnclave struct {
    // AWS SDK v2を使用
    // EC2インスタンス管理
    // Nitro Enclave起動・監視
    // Attestation処理
}
```

#### 2. Attestation Token生成の変更
- GCP Confidential Space用の`gen_custom_token`を、AWS Nitro Enclaves用に書き換え
- `/run/container_launcher/teeserver.sock` → AWS Nitro Enclaves APIに変更

#### 3. ストレージ統合
- MinIO/GCS → S3への切り替え
- IAM Roleベースの認証に変更

#### 4. イメージビルド
- Kaniko（K8s Job）の継続利用、またはAWS CodeBuildへの移行

### デプロイ手順概要

1. **EKSクラスタ作成**
   ```bash
   eksctl create cluster --name manatee-cluster --region us-east-1 --node-type m5.xlarge
   ```

2. **RDS・S3・ECRの準備**
   - RDS MySQL 8.0インスタンス作成
   - S3バケット作成（データ保存用）
   - ECRリポジトリ作成

3. **Nitro Enclaves対応インスタンス追加**
   - EKSノードグループにNitro Enclaves対応インスタンス追加
   - Enclave用のIAMロール設定

4. **ManaTEE AWS版のビルド・デプロイ**
   - TEE Backend実装の追加
   - Helmチャートの設定変更（RDS/S3エンドポイント等）
   - `kubectl apply`でデプロイ

### 制約・注意事項
- **現状はGCP専用**: 公式にはAWS対応なし（改修必要）
- **Nitro Enclavesの制約**: メモリ・CPUリソース上限、ネットワーク制限
- **開発工数**: TEE Backend実装、Attestation処理で数週間～数ヶ月の開発が必要

### 代替案：GCP継続利用
AWS上でManaTEEを動かすよりも、**GCP Confidential Spaceで継続利用する方が現実的**です。現在の実装がGCP向けに最適化されているためです。

## 1. ローカル環境構築

環境構築に必要なすべてのステップは `build.sh` にまとめられています。

### 前提条件

スクリプトは以下のツールが不足している場合、自動でインストールを試みます。
- Docker
- Bazelisk
- Minikube
- kubectl
- mc (MinIO Client)

### 実行

リポジトリのルートディレクトリで以下のコマンドを実行してください。

```bash
bash build.sh
```

このコマンドは、既存のMinikubeクラスタを削除した後、新しいクラスタの作成、コンテナイメージのビルド、Kubernetesリソース（MinIO, MySQL）の作成、そしてHelmによるManateeとJupyterHubのデプロイまで、すべてを自動で行います。

## 2. チュートリアルの実行

環境構築が完了したら、チュートリアル用のデータを準備し、JupyterLabで分析を実行します。

### データ準備

`tutorials` ディレクトリに移動し、データ準備用のスクリプトを実行します。

```bash
cd tutorials && bash run_tutorial_jp.sh
```

このスクリプトは、Minikube上で動作しているMinIOオブジェクトストレージに接続し、チュートリアルに必要なデータ（`stage1`, `stage2` バケットとCSVファイル）を自動で準備します。

### JupyterLabでの操作

`run_tutorial_jp.sh` の実行が完了すると、ターミナルに後続の作業手順が表示されます。その案内に従い、JupyterLabにアクセスし、ノートブックを実行してください。

### ２社間データ突合サンプル

JupyterLabにブラウザでアクセスし以下の3ファイルをアップロードして、`merge_analysis.ipynb`を実行してください。

- purchases.csv
    ```csv
    user_id,email,phone,purchase_amount,purchase_date
    b1a8c1e7...,e1cbb0c4...,c1a5298f...,1200,2025-09-01
    c2b7a1d2...,b2cbb1d5...,d2b5399g...,3400,2025-09-02
    c3c8a2e3...,c3cbb2e6...,e3c5390h...,560,2025-09-03
    d4d9b3f4...,d4cbb3f7...,f4d5391i...,780,2025-09-04
    ```
- exposures.csv
    ```csv
    user_id,email,phone,ad_id,exposure_date
    b1a8c1e7...,e1cbb0c4...,c1a5298f...,A01,2025-08-31
    c3c8a2e3...,c3cbb2e6...,e3c5390h...,A02,2025-09-03
    e5e0b4g5...,e5cbb4g8...,g5e5392j...,A03,2025-09-05
    ```
- merge_analysis.ipynb

実行結果は以下の通りです。
![JupyterLab実行結果](merge_analysis.ipynb.png)

`purchases.csv`と`exposures.csv`はuser_idとemailとphoneを「SHA256でハッシュ化した値（ダミー値）」にしています。  
実際はデータをやり取りする２社間でハッシュ化の具体的なルールと統一してください。  

1. アルゴリズム
    - SHA256やSHA512などの安全なハッシュ関数を使用します。
1. ソルト
    - 同じ値でも異なるハッシュ値になるよう、事前に合意した「ソルト（追加文字列）」を付与してハッシュ化します。

ハッシュ化例
```python
import hashlib

def hash_value(value, salt="your_salt"):
    return hashlib.sha256((salt + value).encode()).hexdigest()
```