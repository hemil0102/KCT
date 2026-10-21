#!/bin/bash
# Claude설정/ 의 두 파일을 ~/.claude/skills/ 에 스킬로 설치한다.
# 이미 같은 이름이 있으면 덮어쓰지 않고 건너뛴다.
set -e
cd "$(dirname "$0")"
DEST="$HOME/.claude/skills"

install_skill() {   # $1=원본 파일  $2=스킬 이름  $3=설명(큰따옴표 없이)
  [ -f "$1" ] || { echo "원본 없음: $1"; exit 1; }
  if [ -e "$DEST/$2" ]; then echo "건너뜀(이미 있음): $DEST/$2"; return; fi
  mkdir -p "$DEST/$2"
  { printf -- '---\nname: %s\ndescription: "%s"\n---\n\n' "$2" "$3"; cat "$1"; } > "$DEST/$2/SKILL.md"
  echo "설치함: $DEST/$2/SKILL.md"
}

install_skill 01_working-agreement.md working-agreement "모든 코딩 프로젝트의 세션 시작·작업·검증 때 따를 범용 작업 약속: 먼저 읽고 파악, 테스트 동반, 증거 기반 통과 보고, 모른다는 것 표시."
install_skill 02_learning-mode.md learning-mode "프로젝트 CLAUDE.md 에 「학습 모드: 켬」이 적혀 있을 때만 사용: AI 는 코드를 제시하고 사용자가 직접 옮겨 치며 배우는 방식(설명, 질문, 작성, 검토)."
echo "끝. 설치된 스킬:"; ls "$DEST"
