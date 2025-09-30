# FT-Transformer Recommender

このリポジトリは、ブログ記事["テーブルデータをベクトル化！FT-Transformerによる推薦システム構築"](https://zenn.dev/xxkuboxx/articles/86b91e4426d4fa)の実験を再現するためのものです。

Instacartの公開データセットを使い、FT-Transformerを用いた推薦モデルの構築から評価までを、Dockerコンテナ上のJupyterLabで一気通貫に実行できます。

-----

## プロジェクトの構成

環境構築を始める前に、リポジトリをクローンし、以下のようなディレクトリ構成になっていることを確認してください。`Instacart_dataset`ディレクトリ配下には https://www.kaggle.com/datasets/psparks/instacart-market-basket-analysis からダウンロードしてきたファイルを手動で配置します。

```
/FT-Transformer-Recommender (リポジトリのルート)
├── Instacart_dataset/
│   ├── aisles.csv
│   ├── departments.csv
│   ├── orders.csv
│   ├── order_products__prior.csv
│   └── products.csv
├── tmp_data/ (ノートブック実行時に自動生成されます)
├── 01_feature_engineering.ipynb
├── 02_preprocess.ipynb
├── 03_model_training.ipynb
├── 04_evaluation_and_inference.ipynb
├── Dockerfile
├── requirements.txt
└── README.md
```

-----

## 環境構築と実験の手順

### Step 1: 前提条件のチェックリスト

PCが以下の条件を満たしているか確認してください。

  - **Docker Desktop**のインストール
  - **NVIDIA GPU**の搭載
  - **最新のNVIDIAドライバ**のインストール
      - 古いドライバではGPUを認識できません。
      - [NVIDIAドライバ公式ページ](https://www.nvidia.co.jp/Download/index.aspx?lang=jp)から最新版をインストールしてください。
  - **(Windowsユーザーのみ) WSL2**の有効化と、**NVIDIAドライバのWSL2対応**
      - Docker Desktopの設定でWSL2バックエンドを使用していることを確認してください。

**動作確認**
PowerShellやターミナルで `wsl` と入力してWSL環境に入り、`nvidia-smi` コマンドを実行してください。GPUの情報が表示されれば準備OKです。失敗する場合は、ドライバの再インストールやPCの再起動を試してください。

### Step 2: データセットのダウンロードと配置

この実験には**Instacart Market Basket Analysis**データセットが必要です。

1.  [Kaggleのデータセットページ](https://www.kaggle.com/datasets/psparks/instacart-market-basket-analysis)にアクセスします。（Kaggleアカウントが必要です）
2.  `Download`ボタンをクリックし、`archive.zip`ファイルをダウンロードします。
3.  ダウンロードしたzipファイルを解凍します。
4.  解凍して出てきた **全てのCSVファイル** (`orders.csv`, `products.csv`など) を、`Instacart_dataset` ディレクトリの中に移動させます。

### Step 3: Dockerイメージのビルド

リポジトリのルートディレクトリ（`Dockerfile`がある場所）でターミナルを開き、以下のコマンドを実行してDockerイメージをビルドします。

```powershell
docker build -t ftt-recommender:latest .
```

この処理には数分かかります。ベースイメージのダウンロードとライブラリのインストールが行われます。

### Step 4: JupyterLabコンテナの起動と実験実行

イメージのビルドが完了したら、以下のコマンドでJupyterLabコンテナを起動します。

**Windows (PowerShell) の場合:**

```powershell
# -d: バックグラウンドで実行
# --gpus all: コンテナからGPUを利用
# --name ftt-lab: コンテナに名前をつける
# -p 8888:8080: ホストPCの8888番ポートをコンテナの8080番ポートに接続
# -v "$(Get-Location):/home/jupyter/work": 現在のフォルダをコンテナ内にマウント
docker run -d --gpus all --name ftt-lab -p 8888:8080 -v "$(Get-Location):/home/jupyter/work" ftt-recommender:latest
```

**Linux / macOS の場合:**

```bash
docker run -d --gpus all --name ftt-lab -p 8888:8080 -v "$(pwd):/home/jupyter/work" ftt-recommender:latest
```

コンテナが起動したら、Webブラウザで **`http://localhost:8888`** にアクセスしてください。
JupyterLabの画面が表示されたら、以下の順番でノートブックを実行していくだけで、ブログ記事の実験が全て再現されます。

1.  `01_feature_engineering.ipynb`
2.  `02_preprocess.ipynb`
3.  `03_model_training.ipynb`
4.  `04_evaluation_and_inference.ipynb`

-----

## コンテナの日常的な操作

一度コンテナを作成した後は、`run`コマンドを再実行する必要はありません。

  - **コンテナを一時停止する:** `docker stop ftt-lab`
  - **停止したコンテナを再開する:** `docker start ftt-lab`

作業を中断・再開する際は、これらのコマンドを使用してください。

-----

<br>

<details><summary><strong>【参考】Dockerfileの中身について</strong></summary>

このDockerfileは、「GCP公式のDeep Learning Containerイメージを、GCP環境外のローカルPCで動作させる」という課題を解決するために、いくつかの工夫をしています。これにより、GCP上でより高性能なGPUで高速に訓練したい時に、全く同じイメージを使うことでバージョン等の依存関係の問題に躓くことなく、実験を再現できるメリットがあります。

#### 1. PyTorchの依存関係問題

`pip`で`sentence-transformers`などをインストールすると、依存関係解決の過程で、CUDA対応の`torch`がCPU版に**上書きされてしまう**問題があります。

**解決策:**
`--no-deps`フラグを活用し、①ライブラリ本体を依存関係無視でインストール → ②`torch`を除いた依存ライブラリを手動でインストール、という方法を採用。これにより、CUDA環境を確実に保護しています。

#### 2. GCP固有のJupyterLab拡張機能の問題

ベースイメージに含まれる`beatrix_jupyterlab`などのGCP連携用拡張機能は、ローカル環境では存在しないGCPサービスに接続しようとしてエラーとなり、JupyterLab全体の起動を妨げます。

**解決策:**
`RUN jupyter labextension disable <拡張機能名>`コマンドで、問題となる拡張機能を明示的に無効化し、クリーンな起動を実現しています。

#### 3. 起動コマンドの上書き

ベースイメージのデフォルト起動コマンドは、GCPのメタデータサーバーへの接続試行など、ローカル環境では不要かつエラーの原因となる処理を含んでいます。

**解決策:**
`CMD`命令でコンテナの起動コマンドを、認証トークンを無効にし、ローカルでの動作に最適化された安全な`jupyter lab`コマンドに上書きしています。

</details>

