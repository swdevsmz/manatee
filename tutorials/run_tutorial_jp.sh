#!/bin/sh

###############################################################
# ■ このチュートリアルのシナリオについて
#
# このチュートリアルは、Manateeが解決する典型的な課題を示します。
#
# 1. 2種類のデータ (Stage-1 と Stage-2)
#
#  - Stage-2: `stage2/insurance.csv` は、個人の医療費などの機密情報を含む
#             「本番データ」です。データサイエンティストは、プライバシー保護の観点から
#             この生データに直接アクセスすることはできません。
#
#  - Stage-1: `stage1/insurance.csv` は、Stage-2のデータから生成された
#             「合成データ（Synthetic Data）」です。統計的な特徴は維持しつつ、
#             差分プライバシーという技術で個人の特定ができないように加工されています。
#
# 2. Jupyter上での開発とセキュアな本番実行
#
#  - 開発フェーズ (JupyterLab):
#    データサイエンティストは、安全な「合成データ(Stage-1)」を使って、
#    データの傾向分析(EDA)やモデル作成のコード（insurance.ipynb）を開発します。
#    これにより、機密データに触れることなく、分析ロジックを自由に試行錯誤できます。
#
#  - 本番実行フェーズ (Manatee Job):
#    開発したノートブックをManateeにジョブとして投入すると、Manateeは
#    TEE（Trusted Execution Environment）と呼ばれるセキュアな隔離環境でコードを実行します。
#    その際、データの入力が自動的に「本番データ(Stage-2)」に切り替えられます。
#
# 【ポイント】
# データサイエンティストは、コードを変更することなく、安全なデータで開発した
# 分析ロジックを、セキュアな環境で本番データに対して実行できます。
# これがManateeの提供する価値です。
###############################################################


# ■■■■■■■■ Minikube環境向けチュートリアルデータ準備スクリプト ■■■■■■■■
#
# このスクリプトは、Minikube環境でチュートリアルを実行するために必要な
# データプロビジョニングを自動化します。
# Minikube内で動作しているMinIO（オブジェクトストレージ）に接続し、
# チュートリアル用のバケット作成とデータアップロードを行います。
#
# ■■■■■■■■ 実行前の前提条件 ■■■■■■■■
# 1. Minikubeクラスタが起動しており、Manateeがデプロイ済みであること。
#    (プロジェクトの build.sh や deployment/minikube/deploy.sh が実行済みであること)
# 2. `mc` (MinIO Client) がインストール済みであること。
#    インストール方法: https://min.io/docs/minio/linux/reference/minio-client.html
# 3. `kubectl` がMinikubeクラスタを指していること。
# ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

set -e

# --- ポートフォワードの管理 ---
# スクリプト終了時にバックグラウンドのポートフォワードを全て終了させる
trap 'echo "\nすべてのポートフォワードを終了します..."; kill 0' EXIT

echo "--- MinIO API (9000) と JupyterHub (8080) へのポートフォワードを開始します ---"
# MinIO API (mcクライアント用)
kubectl port-forward -n manatee service/minio-service 9000:9000 > /dev/null 2>&1 &
# JupyterHub
kubectl port-forward -n manatee service/proxy-public 8080:http > /dev/null 2>&1 &

echo "ポートフォワードが有効になるのを待っています..."
sleep 3

# --- データプロビジョニング ---
echo "--- MinIOクライアント(mc)を設定します ---"
# ローカルのMinIOに 'local' というエイリアスを設定
# デフォルトの認証情報 (minioadmin/minioadmin) を使用
mc alias set local http://127.0.0.1:9000 minioadmin minioadmin

echo "--- バケットを作成します ---"
# ステージ1とステージ2のバケットを作成（存在しない場合のみ）
mc mb --ignore-existing local/stage1
mc mb --ignore-existing local/stage2
echo "バケット: local/stage1, local/stage2"

echo "--- チュートリアルデータをアップロードします ---"
# tutorials/data ディレクトリにいることを想定
if [ -d "./data/stage1" ] && [ -d "./data/stage2" ]; then
    mc cp ./data/stage1/insurance.csv local/stage1/insurance.csv
    mc cp ./data/stage2/insurance.csv local/stage2/insurance.csv
    echo "データのアップロードが完了しました。"
else
    echo "警告: 'data/stage1' または 'data/stage2' ディレクトリが見つかりません。"
    echo "このスクリプトは 'tutorials' ディレクトリから実行してください。"
    exit 1
fi

echo "--- データプロビジョニングが正常に完了しました ---"


# --- 後続作業の案内 ---
echo ""
echo "--------------------------------------------------"
echo "■ 次のステップ：JupyterLabでのチュートリアル実行"
echo "--------------------------------------------------"
echo ""
echo "1. ブラウザで http://localhost:8080 を開き、JupyterHubにアクセスします。"
echo "   (ID/パスワードは共に 'manatee' です)"

echo "2. JupyterLabのファイルブラウザに、'tutorials/code' ディレクトリを丸ごとアップロードします。"

echo "3. アップロードした 'insurance.ipynb' を開き、上から順番にセルを実行してください。"
echo "   (データ取得用のコードはMinIOを参照するように修正済みです)"

echo "--------------------------------------------------"
echo "■ (オプション) MinIO Webコンソールへのアクセス方法"
echo "--------------------------------------------------"
echo "バケットやアップロードされたデータを確認したい場合は、"
echo "新しいターミナルを開いて以下のコマンドを実行してください。"
echo "このコマンドは実行したままにしておく必要があります。"

echo "   kubectl port-forward -n manatee service/minio-service 9090:9090"

echo "その後、ブラウザで http://127.0.0.1:9090 を開き、以下の情報でログインします。"
echo "ユーザー名: minioadmin"
echo "パスワード: minioadmin"
echo "--------------------------------------------------"


echo ""
echo "このスクリプトはポートフォワードをバックグラウンドで実行し続けています。"
echo "終了するには Ctrl+C を押してください。"

# スクリプトがすぐに終了しないように待機
wait