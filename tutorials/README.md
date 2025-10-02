# ManaTEE チュートリアル

このディレクトリには、ManaTEEのチュートリアルとサンプルデータが含まれています。

## ディレクトリ構成

```
tutorials/
├── README.md                    # このファイル
├── tutorial.sh                  # チュートリアル実行スクリプト（英語版）
├── run_tutorial_jp.sh          # チュートリアル実行スクリプト（日本語版）
├── merge_analysis.ipynb.png    # チュートリアル実行結果のスクリーンショット
├── code/                        # サンプルノートブック
│   ├── merge_analysis.ipynb    # ２社間データ突合サンプル
│   ├── insurance.ipynb         # 保険データ分析サンプル
│   ├── regression.ipynb        # 回帰分析サンプル
│   └── sdk/                    # ManaTEE SDK実装
└── data/                        # サンプルデータ
    ├── stage1/                  # ステージ1データ（企業A）
    │   └── purchases.csv       # 購買データサンプル
    └── stage2/                  # ステージ2データ（企業B/TikTok）
        └── exposures.csv       # 広告接触データサンプル
```

---

## チュートリアル一覧

### 1. ２社間データ突合サンプル

**ノートブック**: [`code/merge_analysis.ipynb`](code/merge_analysis.ipynb)

企業Aの購買データとTikTokの広告接触データを突合し、広告のコンバージョン効果を分析します。

**使用データ**:
- Stage 1: [`data/stage1/purchases.csv`](data/stage1/purchases.csv) - 購買データ（SHA256ハッシュ化済み）
- Stage 2: [`data/stage2/exposures.csv`](data/stage2/exposures.csv) - 広告接触データ（SHA256ハッシュ化済み）

**学べること**:
- ハッシュ化されたデータの突合方法
- アトリビューション期間の設定
- コンバージョン率の計算
- ManaTEE SDKの基本的な使い方

---

### 2. 保険データ分析サンプル

**ノートブック**: [`code/insurance.ipynb`](code/insurance.ipynb)

保険データの相関分析と予測モデルの構築。

**学べること**:
- 相関分析
- データの前処理
- 統計的な分析手法

---

### 3. 回帰分析サンプル

**ノートブック**: [`code/regression.ipynb`](code/regression.ipynb)

回帰分析を使った予測モデルの構築。

**学べること**:
- 線形回帰
- モデルの評価
- 予測精度の向上

---

## 実行方法

### 方法1: 自動セットアップスクリプト（推奨）

```bash
# Minikube環境でデータを自動セットアップ
cd tutorials
bash run_tutorial_jp.sh
```

このスクリプトは以下を自動実行します：
1. MinIOへの接続
2. `stage1`、`stage2` バケットの作成
3. サンプルデータのアップロード
4. JupyterLabアクセス情報の表示

### 方法2: 手動実行

1. **JupyterLabにアクセス**
   ```bash
   minikube service jupyter -n jupyterhub --url
   ```

2. **ノートブックを開く**
   - ブラウザでJupyterLabにアクセス
   - `tutorials/code/merge_analysis.ipynb` を開く

3. **ノートブックを実行**
   - セルを順番に実行（Shift+Enter）

---

## データ形式

### purchases.csv (企業A: 購買データ)

| カラム | 説明 | 例 |
|-------|------|-----|
| `user_id` | ユーザーID（SHA256ハッシュ化） | `b1a8c1e7...` |
| `email` | メールアドレス（SHA256ハッシュ化） | `e1cbb0c4...` |
| `phone` | 電話番号（SHA256ハッシュ化） | `c1a5298f...` |
| `purchase_amount` | 購入金額 | `1200` |
| `purchase_date` | 購入日 | `2025-09-01` |

### exposures.csv (企業B: 広告接触データ)

| カラム | 説明 | 例 |
|-------|------|-----|
| `user_id` | ユーザーID（SHA256ハッシュ化） | `b1a8c1e7...` |
| `email` | メールアドレス（SHA256ハッシュ化） | `e1cbb0c4...` |
| `phone` | 電話番号（SHA256ハッシュ化） | `c1a5298f...` |
| `ad_id` | 広告ID | `A01` |
| `exposure_date` | 広告接触日 | `2025-08-31` |

**注意**: すべての個人識別情報（PII）は、**同じソルト**を使用してSHA256でハッシュ化されています。

---

## ハッシュ化について

### ハッシュ化の目的

Data Clean Roomでは、生データを共有せず、ハッシュ化されたデータのみを使用します。これにより：

- ✅ プライバシーを保護
- ✅ 元のデータを復元不可能に
- ✅ 一致するレコードのみを特定可能

### ハッシュ化の実装例

```python
import hashlib

def hash_value(value, salt="your_secret_salt"):
    """
    値をSHA256でハッシュ化
    
    Args:
        value: ハッシュ化する値
        salt: ソルト（両社で事前に合意）
    
    Returns:
        ハッシュ化された値（16進数文字列）
    """
    return hashlib.sha256((salt + value).encode()).hexdigest()

# 使用例
email = "user@example.com"
salt = "agreed_secret_salt_2025"
hashed_email = hash_value(email, salt)
print(f"元の値: {email}")
print(f"ハッシュ値: {hashed_email}")
```

### 重要なポイント

1. **ソルトの共有**: 両社で同じソルトを使用（オフラインまたは暗号化通信で共有）
2. **アルゴリズムの統一**: SHA256を使用
3. **エンコーディング**: UTF-8を使用
4. **フォーマット**: 16進数文字列で出力

---

## トラブルシューティング

### データが読み込めない

```python
# MinIOの接続確認
import os
print(f"S3 Endpoint: {os.environ.get('S3_ENDPOINT')}")
print(f"Execution Stage: {os.environ.get('EXECUTION_STAGE')}")
```

### ノートブックが実行できない

1. カーネルを再起動: `Kernel` → `Restart Kernel`
2. 必要なパッケージをインストール:
   ```python
   !pip install pandas numpy matplotlib
   ```

### Attestation Tokenが生成できない

Minikube環境では、Mock実装を使用しているため、実際のAttestation Tokenは生成されません。本番環境（GCP Confidential Space）でのみ実際のトークンが生成されます。

---

## 関連ドキュメント

- [SETUP_MINIKUBE.md](../SETUP_MINIKUBE.md) - ローカル環境セットアップ
- [USECASE.md](../USECASE.md) - 詳細なユースケース解説
- [FUNCTION.md](../FUNCTION.md) - ManaTEE SDK API リファレンス
- [BUILD.md](../BUILD.md) - 本番環境へのデプロイ

---

## 次のステップ

1. ✅ チュートリアルを実行
2. ✅ サンプルデータを理解
3. ✅ 独自のデータで分析を試す
4. ✅ 本番環境（GCP）へのデプロイを検討

ご質問やフィードバックは、GitHubのIssueでお願いします！
