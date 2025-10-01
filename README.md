# ManaTEE on Minikube (ローカル開発環境)

このドキュメントは、Minikubeを使用してローカルPC上にManaTEEのテスト環境を構築し、チュートリアルを実行する手順について説明します。オリジナルのREADMEは `README.original.md` にリネームされています。

## 概要

開発とテストを容易にするため、GCP環境を必要としないMinikubeベースのセットアップが用意されています。`build.sh` スクリプトは、必要なツールのインストールからManateeのデプロイまで、環境構築の全プロセスを自動化します。

**注意:** この環境は実際のTEE（Trusted Execution Environment）を使用しないため、セキュリティ機能の検証ではなく、アプリケーションの動作確認や開発を目的としています。

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