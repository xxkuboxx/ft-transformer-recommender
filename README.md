# FT-Transformer Recommender - 開発環境構築ガイド

このリポジトリは、Instacartデータセットを用いたFT-Transformerによる推薦モデルの実験環境をDockerで構築するためのものです。

最終的なゴールは、ローカルPCでの開発とGCP（Google Cloud Platform）上での実行の両方で、完全に同一の環境を再現することです。このため、ベースイメージにはGCPの公式Deep Learning Containerを採用しています。

## 概要

この環境構築の核心は、**GCP専用に設計されたDockerイメージを、GCPのサービスが存在しないローカルPC上で安定して動作させる**点にあります。
標準的な手順では、GCP固有の拡張機能やライブラリの依存関係が原因で、JupyterLabが正常に起動しません。

## 1. 前提条件

この環境を構築する前に、お使いのPC（ホストマシン）が以下の条件を満たしていることを確認してください。

- **Docker Desktop**がインストールされていること。
- **WSL2 (Windows Subsystem for Linux)** が有効になっていること (Windowsユーザーの場合)。
- **NVIDIA GPU**が搭載されていること。
- **WSL2対応の最新NVIDIAドライバ**がインストールされていること。
    - 古いドライバでは動作しません。
    - [NVIDIAドライバ公式ダウンロードページ](https://www.nvidia.co.jp/Download/index.aspx?lang=jp) から、お使いのGPUに合った最新の「Game Ready」または「Studio」ドライバをインストールしてください。
- **NVIDIA Container Toolkit**がDockerと連携しており、`--gpus all`オプションが利用可能なこと。

**【動作確認】**
PowerShellやターミナルで `wsl` と入力してWSL環境に入り、`nvidia-smi` コマンドが正常に実行できることを確認してください。これが失敗する場合、ドライバのインストールに問題があります。

## 2. 環境構築と利用手順

### ステップ 1: イメージのビルド

このリポジトリ（`Dockerfile`と`requirements.txt`がある場所）のルートで、以下のコマンドを実行してDockerイメージをビルドします。

```powershell
docker build -t ftt-recommender:latest .
```
この処理には数分かかります。Dockerfileや`requirements.txt`を更新した場合は、このコマンドを再実行してイメージを更新してください。

### ステップ 2: コンテナの起動

イメージのビルドが完了したら、以下のコマンドでJupyterLabコンテナを起動します。

**Windows (PowerShell) の場合:**
```powershell
docker run -d --gpus all --name ftt-lab -p 8888:8080 -v "$(Get-Location):/home/jupyter/work" ftt-recommender:latest
```

**Linux / macOS の場合:**
```bash
docker run -d --gpus all --name ftt-lab -p 8888:8080 -v "$(pwd):/home/jupyter/work" ftt-recommender:latest
```
これにより、現在のディレクトリがコンテナ内の`/home/jupyter/work`にマウントされ、ファイルの同期が取られます。

### ステップ 3: JupyterLabへのアクセス

Webブラウザを開き、以下のアドレスにアクセスします。

**`http://localhost:8888`**

トークン認証は無効化されているため、直接JupyterLabのインターフェースが表示されます。

### ステップ 4: コンテナの停止と再開

- **停止:** `docker stop ftt-lab`
- **再開:** `docker start ftt-lab`

一度 `docker run` でコンテナを作成した後は、この停止・再開コマンドで運用してください。

## 3. なぜこのDockerfileは複雑なのか？ (設計思想)

このDockerfileは、いくつかの重要な問題を解決するために、意図的に特定の手順を踏んでいます。

### 3.1. PyTorchの依存関係問題

`pip`の依存関係リゾルバは、`sentence-transformers`などをインストールする際に、PyPIで公開されている標準のCPU版`torch`をインストールしようとします。これを防がないと、**CUDA対応版の`torch`が上書き**されてしまい、GPUが使えなくなります。

**解決策:**
証明済みの**「`--no-deps`を使った三段階インストール戦略」**をDockerfile内で実行しています。
1.  まず、`requirements.txt`内のライブラリ本体を、依存関係を完全に無視してインストールします (`--no-deps`)。
2.  次に、`sentence-transformers`などが必要とする依存ライブラリを、`torch`を除いて手動でインストールします。
3.  これにより、`pip`の自動解決による`torch`の上書きを確実に防ぎ、CUDA環境を保護しています。

### 3.2. GCP固有のJupyterLab拡張機能の問題

GCPのベースイメージには、`beatrix_jupyterlab`や`dataproc_jupyter_plugin`といった、GCP環境との連携を前提とした拡張機能がプリインストールされています。これらがローカル環境で起動しようとすると、存在しないGCPサービスに接続しようとしてクラッシュし、JupyterLab全体の起動失敗を招きます。

**解決策:**
`RUN jupyter labextension disable <拡張機能名>` コマンドを使い、これらの**問題となる拡張機能を明示的に無効化**しています。これにより、JupyterLabはクリーンな状態で起動できます。

### 3.3. 起動コマンドの上書き

ベースイメージのデフォルト起動コマンドは、GCPのメタデータサーバーへの接続など、ローカル環境ではエラーとなる処理を含んでいます。

**解決策:**
`CMD`命令を使い、コンテナのデフォルト起動コマンドを、**認証トークンを無効にし、ローカルでの動作に最適化された安全な`jupyter lab`コマンドに上書き**しています。
