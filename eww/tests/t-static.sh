#!/usr/bin/env bash
# Controlli statici della config eww (nessun effetto sul sistema)
cd "$(dirname "$0")/.." || exit 1
res=0
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 ${3:+[$3]}"; res=1; fi; }

errs=$(for f in scripts/*.sh tests/*.sh; do bash -n "$f" 2>&1; done)
t "sintassi bash di tutti gli script" '[ -z "$errs" ]' "$errs"
perr=$(python3 -m py_compile scripts/*.py tests/*.py 2>&1); rm -rf scripts/__pycache__ tests/__pycache__
t "sintassi python" '[ -z "$perr" ]' "$perr"
nx=$(for f in scripts/*.sh scripts/*.py; do case "$f" in scripts/lib.sh|scripts/mpris_watch.py) continue ;; esac; [ -x "$f" ] || echo "$f"; done)  # librerie escluse
t "script eseguibili" '[ -z "$nx" ]' "$nx"
miss=$(grep -ohE 'scripts/[A-Za-z0-9_.-]+' *.yuck scripts/* | sort -u | while read s; do [ -f "$s" ] || echo "$s"; done)
t "script citati esistono" '[ -z "$miss" ]' "$miss"
bal=$(for f in *.yuck; do python3 - "$f" <<'PY'
import sys, re
s = open(sys.argv[1]).read()
s = re.sub(r'`[^`]*`', '', s); s = re.sub(r'"(\\.|[^"\\])*"', '', s); s = re.sub(r';[^\n]*', '', s)
d = 0
for c in s:
    d += (c == '(') - (c == ')')
    if d < 0: break
if d: print(sys.argv[1])
PY
done)
t "parentesi bilanciate nei .yuck" '[ -z "$bal" ]' "$bal"

# ogni "eww ... open" negli script deve usare --no-daemonize (B1), tranne
# recover.sh e l'autostart, gli unici punti che possono avviare un daemon
bad=$(grep -nE '(^|[^_a-z])eww( |")[^|]*\bopen(-many)?\b' scripts/*.sh scripts/*.py | grep -v -- '--no-daemonize' | grep -vE '^scripts/recover.sh|^\S+:\s*#|eww_open_verified|eww_ open')
t "nessun 'eww open' che possa avviare un secondo daemon" '[ -z "$bad" ]' "$bad"
py_open=$(grep -n '"open"' scripts/session.py | head -1)
t "session.py apre con EWW (--no-daemonize)" 'grep -q "EWW = \[\"eww\", \"--no-daemonize\"" scripts/session.py'

# classi CSS che coincidono col nome di una finestra (B11): ammesse solo bar e closer
coll=$(for w in $(grep -oE '^\(defwindow [a-z-]+' windows.yuck | awk '{print $2}'); do
  case $w in bar|closer) continue ;; esac
  grep -qE "(^|[ ,])\.$w( |\{|,|:|$)" eww.scss && echo ".$w"; done)
t "nessuna classe CSS uguale al nome di una finestra" '[ -z "$coll" ]' "$coll"

# nessun valore inserito tra apici nei comandi onclick (B6)
q=$(grep -nE ":onclick[^\n]*'\\\$\{" *.yuck)
t "nessun valore tra apici nei comandi onclick" '[ -z "$q" ]' "$q"

# colori: tutti quelli usati nello stile sono generati da matugen
miss_col=$(python3 - <<'PY'
import re, os
scss = open("eww.scss").read()
used = set(re.findall(r"\$([a-z_][a-z0-9_-]*)", scss))
local = set(re.findall(r"^\s*\$([a-z_][a-z0-9_-]*)\s*:", scss, re.M))
cur = set(re.findall(r"\$([a-z_]+)\s*:", open("colors.scss").read()))
print(" ".join(sorted(used - local - cur)))
PY
)
t "tutti i colori usati esistono in colors.scss" '[ -z "$miss_col" ]' "$miss_col"
t "il template matugen genera tutti i colori (ciclo su colors)" 'grep -q "for name, value in colors" ~/.config/matugen/templates/eww-colors.scss'
exit $res
