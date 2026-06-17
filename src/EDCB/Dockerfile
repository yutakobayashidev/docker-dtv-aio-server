# ビルドステージ
FROM debian:bookworm-slim AS builder

# ビルド時の依存パッケージをインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    make \
    gcc \
    g++ \
    liblua5.2-dev \
    lua-zlib \
    curl \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# EDCBのソースをコピーしてビルド
COPY ./EDCB/EDCB /tmp/EDCB
WORKDIR /tmp/EDCB/Document/Unix
RUN make -j "$(nproc)" && \
    make install && \
    make extra -j "$(nproc)" && \
    make install_extra && \
    mkdir -p /var/local/edcb && \
    make setup_ini && \
    sed -i -e 's/^ALLOW_SETTING=.*/ALLOW_SETTING=true/' \
    /var/local/edcb/HttpPublic/legacy/util.lua

# EDCB Material WebUIをコピー
COPY ./EDCB/EDCB_Material_WebUI /tmp/EDCB_Material_WebUI
WORKDIR /tmp/EDCB_Material_WebUI
RUN cp -r HttpPublic /var/local/edcb/ && \
    cp -r Setting /var/local/edcb/

# BonDriver_LinuxMirakcをビルド
COPY ./EDCB/BonDriver_LinuxMirakc /tmp/BonDriver_LinuxMirakc
WORKDIR /tmp/BonDriver_LinuxMirakc
RUN make -j "$(nproc)"

# BonDriver_LinuxMirakcをインストール
RUN cp BonDriver_LinuxMirakc.so /usr/local/lib/edcb/BonDriver_LinuxMirakc.so
RUN cp BonDriver_LinuxMirakc.so /usr/local/lib/edcb/BonDriver_LinuxMirakc_T.so
RUN cp BonDriver_LinuxMirakc.so /usr/local/lib/edcb/BonDriver_LinuxMirakc_S.so

COPY ./EDCB/BonDriver_LinuxMirakc.so.example.ini /usr/local/lib/edcb/BonDriver_LinuxMirakc.so.ini
COPY ./EDCB/BonDriver_LinuxMirakc.so.example.ini /usr/local/lib/edcb/BonDriver_LinuxMirakc_T.so.ini
COPY ./EDCB/BonDriver_LinuxMirakc.so.example.ini /usr/local/lib/edcb/BonDriver_LinuxMirakc_S.so.ini

# AmatsukazeAddTaskを取得ステージ
FROM alpine:3.20 AS fetch

RUN apk add --no-cache ca-certificates curl jq xz tar

ENV UBUNTU_VERSION=24.04
WORKDIR /work

RUN curl -fsSL https://api.github.com/repos/rigaya/Amatsukaze/releases/latest \
    | jq -r '.assets[].browser_download_url' \
    | grep "Ubuntu${UBUNTU_VERSION}.*tar.xz" \
    | head -n1 > url.txt

RUN set -eux; \
    URL="$(cat url.txt)"; \
    test -n "$URL"; \
    curl -fSL "$URL" -o amatsukaze.tar.xz

RUN mkdir -p /out \
    && xz -dc amatsukaze.tar.xz | tar -x -C /out

# ランタイムステージ
FROM ubuntu:24.04 AS runtime

# ランタイム依存パッケージのみインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    liblua5.2-0 \
    lua-zlib \
    ffmpeg \
    ca-certificates \
    curl \
    python3 \
    python3-pip \
    patch && \
    rm -rf /var/lib/apt/lists/*

# Python 依存パッケージをインストール
RUN pip3 install --break-system-packages requests ruamel.yaml colorama 'mastodon.py' jaconv twitter zstandard

# ビルドステージから必要なファイルをコピー
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/lib/edcb/ /usr/local/lib/edcb/
COPY --from=builder /var/local/edcb/ /var/local/edcb/

# EDCBの作業ディレクトリを作成してパーミッション設定
RUN mkdir -p /var/local/edcb && \
    chmod 777 /var/local/edcb


# AmatsukazeAddTaskを取得ステージからコピー
COPY --from=fetch /out/exe_files/AmatsukazeAddTask /usr/local/bin/

# EDCBNotifier をコピー
COPY ./EDCBNotifier/EDCBNotifier/EDCBNotifier.py /var/local/edcb/EDCBNotifier/
COPY ./EDCBNotifier/EDCBNotifier/SendDiscord.py /var/local/edcb/EDCBNotifier/
COPY ./EDCBNotifier/EDCBNotifier/SendLINE.py /var/local/edcb/EDCBNotifier/
COPY ./EDCBNotifier/EDCBNotifier/SendTwitter.py /var/local/edcb/EDCBNotifier/
COPY ./EDCBNotifier/EDCBNotifier/SendMastodon.py /var/local/edcb/EDCBNotifier/
COPY ./EDCBNotifier/EDCBNotifier/Utils.py /var/local/edcb/EDCBNotifier/
# EDCBNotifier の Linux 対応パッチを適用 (StartTime/DurationSecond マクロ対応)
COPY ./EDCB/EDCBNotifier-linux.patch /tmp/EDCBNotifier-linux.patch
RUN patch -d /var/local/edcb -p1 < /tmp/EDCBNotifier-linux.patch && \
    rm /tmp/EDCBNotifier-linux.patch
COPY ./EDCB/EDCBNotifier/EDCBNotifier.yaml /var/local/edcb/EDCBNotifier/EDCBNotifier.default.yaml
COPY ./EDCB/EDCBNotifier/PostAddReserve.sh /var/local/edcb/EDCBNotifier/
COPY ./EDCB/EDCBNotifier/PostChgReserve.sh /var/local/edcb/EDCBNotifier/
COPY ./EDCB/EDCBNotifier/PostRecStart.sh /var/local/edcb/EDCBNotifier/
COPY ./EDCB/EDCBNotifier/PostRecEnd.sh /var/local/edcb/EDCBNotifier/
COPY ./EDCB/EDCBNotifier/PostNotify.sh /var/local/edcb/EDCBNotifier/
RUN chmod +x /var/local/edcb/EDCBNotifier/*.sh

# EDCB が Post*.sh を見つけられるようシンボリックリンク
RUN for script in PostAddReserve PostChgReserve PostRecStart PostRecEnd PostNotify; do \
      ln -s /var/local/edcb/EDCBNotifier/${script}.sh /var/local/edcb/${script}.sh; \
    done

# 作業ディレクトリを設定
WORKDIR /var/local/edcb

# ポート番号（必要に応じて調整）
EXPOSE 5510 8888

# エントリーポイント
ENTRYPOINT ["/usr/local/bin/EpgTimerSrv"]
