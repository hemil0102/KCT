#!/bin/bash
# 더블클릭: assets 의 그림으로 HTML 을 다시 만든다
cd "$(dirname "$0")" && /usr/bin/python3 build.py
echo ""; echo "끝! 창을 닫아도 돼요."
