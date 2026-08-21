#!/usr/bin/env bash
# Синхронізує локальну систему /cmo → цей репозиторій → GitHub.
# Приватний контекст бізнесу НЕ публікується: замість нього шаблон.
# Запуск:  ~/cmo-system/sync.sh  ["текст коміту"]
set -euo pipefail

SRC_AGENTS="$HOME/.claude/agents"
SRC_SKILL="$HOME/.claude/skills/cmo"
REPO="$HOME/cmo-system"
PRIVATE="tisto-context.md"          # ніколи не публікується

cd "$REPO"

# 1. агенти
rm -f agents/*.md
cp "$SRC_AGENTS"/cmo-*.md agents/

# 2. оркестратор і база знань (крім приватного контексту)
rm -rf skills/cmo/references
mkdir -p skills/cmo/references
cp "$SRC_SKILL/SKILL.md" skills/cmo/
for f in "$SRC_SKILL"/references/*.md; do
  b=$(basename "$f")
  [ "$b" = "$PRIVATE" ] && continue
  cp "$f" skills/cmo/references/
done

# 3. шаблон контексту повертаємо з git (він не в ~/.claude)
git checkout -- skills/cmo/references/business-context.template.md 2>/dev/null || true

# 4. деперсоналізація
python3 - <<'PY'
import pathlib, re
r = pathlib.Path.home()/'cmo-system'
subs = [
    ('tisto-context.md', 'business-context.md'),
    ('Якщо запуск для TISTO, додатково прочитай', 'Якщо заповнено контекст бізнесу, додатково прочитай'),
    ('якщо запуск для TISTO', 'якщо заповнено контекст бізнесу'),
    ('Якщо запуск для TISTO — також', 'Якщо є контекст бізнесу — також'),
    ('Для TISTO — ', 'Якщо є контекст бізнесу — '),
    ('### Контекст TISTO', '### Твій контекст'),
    ('⭐ НАЙБЛИЖЧЕ ДО TISTO:', '⭐ (сервісна модель з обмеженою ємністю):'),
]
for f in list((r/'agents').glob('*.md')) + list((r/'skills/cmo').rglob('*.md')):
    t = f.read_text(); o = t
    for a, b in subs:
        t = t.replace(a, b)
    if t != o:
        f.write_text(t)
PY

# 5. запобіжник: нічого приватного не просочилось
if grep -rIl "TISTO\|Ігор\|ntn_\|ghp_\|sk-" agents skills 2>/dev/null | grep -q .; then
  echo "🛑 СТОП: знайдено приватні дані. Пуш скасовано."
  grep -rIn "TISTO\|Ігор\|ntn_\|ghp_\|sk-" agents skills | head
  exit 1
fi

# 6. коміт і пуш
if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
  echo "✅ змін немає — репозиторій уже актуальний"
  exit 0
fi

MSG="${1:-Оновлення системи /cmo}"
git add -A
git -c user.name="Igor Kliuchnyk" -c user.email="igorkluchnyk@gmail.com" \
  commit -q -m "$MSG

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -q origin main
echo "✅ запушено: $MSG"
echo "   https://github.com/igorkluchnyk-lang/cmo-system"
git log --oneline | head -1
