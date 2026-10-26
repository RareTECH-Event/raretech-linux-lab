#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB="$ROOT/lab"
if [[ -e "$LAB" ]]; then
  echo "既存の lab/ があります。上書きしません。再作成する場合は内容を確認してから lab/ を削除してください。" >&2
  exit 1
fi
mkdir -p "$LAB"/{mission1/{config,backup,archive},mission2,mission3,mission4,mission5/{config,logs,app}}
# M1: scattered configuration, learner finds and moves it.
printf 'APP_NAME=RareTECH\nAPP_PORT=8080\n' > "$LAB/mission1/backup/app.conf"
printf 'readme: app.conf を config/ に復元してください。\n' > "$LAB/mission1/README.txt"
printf 'backup-2026-10-01\n' > "$LAB/mission1/archive/old.txt"
# M2: deterministic sample access logs with identifiable errors.
{
  i=1
  while [[ $i -le 300 ]]; do
    minute=$((i % 60)); second=$((i * 7 % 60))
    ip="192.0.2.$((i % 15 + 1))"
    status=200
    path=/home
    if (( i % 11 == 0 )); then status=404; path=/missing; fi
    if (( i % 37 == 0 )); then status=500; path=/api; ip=198.51.100.77; fi
    printf '2026-10-20T10:%02d:%02dZ %s GET %s %s\n' "$minute" "$second" "$ip" "$path" "$status"
    i=$((i+1))
  done
} > "$LAB/mission2/access.log"
# M3: permissions exercise on lab-owned file, without sudo.
printf 'TRAINING_SECRET=demo-only\n' > "$LAB/mission3/secret.txt"
chmod 000 "$LAB/mission3/secret.txt"
# M4: start manually so setup does not leave a background process.
cat > "$LAB/mission4/worker.sh" <<'WORKER'
#!/usr/bin/env bash
# 演習用。終了するまで待機するだけで、CPU負荷はほぼありません。
while :; do sleep 5; done
WORKER
chmod 755 "$LAB/mission4/worker.sh"
cat > "$LAB/mission4/start.sh" <<'START'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$DIR/worker.pid" ]] && kill -0 "$(cat "$DIR/worker.pid")" 2>/dev/null; then
  echo "すでに起動しています (PID $(cat "$DIR/worker.pid"))"
  exit 0
fi
nohup "$DIR/worker.sh" >/dev/null 2>&1 </dev/null &
echo $! > "$DIR/worker.pid"
echo "演習用プロセスを起動しました。ps と kill を使って停止してください。"
START
chmod 755 "$LAB/mission4/start.sh"
# M5: simple, intentionally invalid configuration and missing required file.
printf 'PORT=not-a-number\nMESSAGE=RareTECH lab OK\n' > "$LAB/mission5/config/app.conf"
printf '2026-10-20 ERROR invalid PORT: not-a-number\n2026-10-20 ERROR missing app/index.html\n' > "$LAB/mission5/logs/app.log"
cat > "$LAB/mission5/check.sh" <<'CHECK'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="$DIR/config/app.conf"
port="$(sed -n 's/^PORT=//p' "$config" | head -n 1)"
if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
  echo 'ERROR: PORT は1〜65535の整数にしてください' >&2
  exit 1
fi
if [[ ! -f "$DIR/app/index.html" ]]; then
  echo 'ERROR: app/index.html がありません' >&2
  exit 1
fi
printf 'OK: PORT=%s, index.html found\n' "$port"
CHECK
chmod 755 "$LAB/mission5/check.sh"
cat > "$LAB/README.txt" <<'DOC'
Mission 1: backup/ にある app.conf を config/ に移動する。
Mission 2: access.log から 404/500 の件数と、500のアクセス元IPを調べる。
Mission 3: secret.txt の所有者だけが読み書きできるようにする (600)。
Mission 4: bash mission4/start.sh で演習用プロセスを起動し、PIDを調べて停止する。
Mission 5: config/app.conf のPORTを有効な整数に直し、app/index.htmlを作って check.sh を成功させる。
DOC
printf '準備完了: %s\n' "$LAB"
printf '課題は lab/README.txt を参照してください。\n'
