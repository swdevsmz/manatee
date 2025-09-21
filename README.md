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
