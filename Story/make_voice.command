#!/bin/bash
# 더블클릭하면 이 폴더의 대사를 호랑이 목소리 파일(voice/*.m4a)로 만든다.
# 목소리 바꾸기: 터미널에서  VOICE=M3 PITCH=0.9 ./make_voice.command
set -e
cd "$(dirname "$0")"
PY=""
for p in /opt/homebrew/bin/python3.14 /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 /opt/homebrew/bin/python3 python3.12 python3.11; do
  if command -v "$p" >/dev/null 2>&1; then
    v=$("$p" -c 'import sys;print(sys.version_info[1])'); if [ "$v" -ge 11 ]; then PY="$p"; break; fi
  fi
done
if [ -z "$PY" ]; then echo "Python 3.11 이상이 필요해요 (brew install python)."; exit 1; fi
VENV="$HOME/.kct_voice_venv"
if [ ! -d "$VENV" ]; then "$PY" -m venv "$VENV"; fi
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q "supertonic==1.3.1" numpy soundfile
"$VENV/bin/python" gen_voice.py
echo ""
echo "끝! 이 창은 닫아도 돼요. HTML 을 다시 열면 호랑이 목소리로 나와요."
