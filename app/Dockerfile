# syntax=docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM python:3.10-alpine AS builder

RUN apk add --no-cache ca-certificates

RUN wget -O /usr/local/bin/ssm-env https://github.com/remind101/ssm-env/releases/download/v0.0.5/ssm-env && \
      cd /usr/local/bin && \
      echo 'babf40382bcd260f0d8d4575a32d5ec33fb08fefd29f12ffd800fbe738c41021  ssm-env' | sha256sum -c && \
      chmod +x ssm-env

WORKDIR /app

COPY requirements.txt /app
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install -r requirements.txt

COPY . /app

ENTRYPOINT ["/usr/local/bin/ssm-env", "-with-decryption"]

CMD ["python3", "app.py"]

FROM builder as dev-envs

RUN <<EOF
apk update
apk add git
EOF

RUN <<EOF
addgroup -S docker
adduser -S --shell /bin/bash --ingroup docker vscode
EOF
# install Docker tools (cli, buildx, compose)
COPY --from=gloursdocker/docker / /