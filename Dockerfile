# ベースイメージとしてGCPのDeep Learning Containerを指定
FROM us-docker.pkg.dev/deeplearning-platform-release/gcr.io/base-cu124.py310:m129

# apt-getを非対話モードで実行するように設定
# USERをrootに切り替えてパッケージをインストール
USER root
ENV DEBIAN_FRONTEND=noninteractive

# システムライブラリを更新し、faiss-gpuのビルドに必要なライブラリをインストール
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    swig \
    libopenblas-dev && \
    rm -rf /var/lib/apt/lists/*

# 依存関係の要であるPyTorchを、CUDA 12.4に最適化されたバージョンでインストール
# これを先にインストールすることで、後の依存関係解決の基準とする
RUN pip install --no-cache-dir \
    torch==2.3.1+cu121 \
    torchvision==0.18.1+cu121 \
    torchaudio==2.3.1+cu121 \
    --index-url https://download.pytorch.org/whl/cu121

# requirements.txtをコンテナにコピー
COPY requirements.txt /tmp/requirements.txt

# requirements.txtを使って残りのライブラリをインストール
# 依存関係の衝突を確実に回避するために、下記の手順でインストールを実行
RUN \
    # 1. requirements.txtに記載のライブラリ本体を、依存関係を完全に無視してインストール
    pip install --no-cache-dir --no-deps -r /tmp/requirements.txt && \
    \
    # 2. sentence-transformersに必要な依存関係を、torchを除外して手動でインストール
    pip install --no-cache-dir "transformers<5.0.0,>=4.41.0" "huggingface-hub>=0.20.0" "accelerate>=0.26.0" && \
    \
    # 3. openpyxlに必要な依存関係を手動でインストール
    pip install --no-cache-dir et-xmlfile && \
    # 4. datasetsのインストール（必要ないibis-frameworkと依存関係が衝突するので事前に削除）
    pip uninstall -y ibis-framework && \ 
    pip install datasets && \ 
    # 5. その他ライブラリのインストール
    pip install umap-learn matplotlib && \ 
    pip install google-generativeai

# ローカル環境でクラッシュの原因となるGCP固有のJupyterLab拡張機能を無効化する
RUN jupyter labextension disable beatrix_jupyterlab && \
    jupyter labextension disable dataproc_jupyter_plugin

# 元のユーザー(jupyter)に戻す
# これにより、JupyterLabやターミナルが適切な権限で動作する
USER jupyter

# 作業ディレクトリを設定 (jupyterユーザーのホームディレクトリ)
WORKDIR /home/jupyter

# コンテナ起動時に実行されるデフォルトコマンドを上書き
# GCP固有の設定をバイパスし、認証トークンなしでJupyterLabを起動する
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8080", "--no-browser", "--notebook-dir=/home/jupyter/work", "--NotebookApp.token=''"]
