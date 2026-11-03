#!/usr/bin/env bash
# media.py con titoli/artisti ostili (player MPRIS FINTO, nessun audio).
# Lancia media.py da solo (non tocca la barra) mentre il player finto è attivo.
cd "$(dirname "$0")" || exit 1
res=0
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 [$out]"; res=1; fi; }
probe(){  # probe <nome> <artista> <titolo> -> JSON di media.py
  python3 fake-mpris.py "$1" Playing "$2" "$3" 4 & local fp=$!; sleep 0.8
  out=$(timeout 2 python3 -u ../scripts/media.py 2>/dev/null | head -1); wait $fp 2>/dev/null
}
[ "$(playerctl -l 2>&1)" = "No players found" ] || echo "  (attenzione: ci sono altri player attivi, playerctl potrebbe scegliere quelli)"
probe ewwt1 "Artista" "Titolo";                t "normale" '[ "$(jq -r .title <<<"$out")" = Titolo ] && [ "$(jq -r .artist <<<"$out")" = Artista ]'
probe ewwt2 $'Art\tista' "Titolo";             t "TAB nell'artista: resta Playing, TAB -> spazio" '[ "$(jq -r .status <<<"$out")" = Playing ] && [ "$(jq -r .artist <<<"$out")" = "Art ista" ]'
probe ewwt3 "Artista" $'Riga1\nRiga2';         t "a capo nel titolo -> una riga" '[ "$(jq -r .title <<<"$out")" = "Riga1 Riga2" ]'
probe ewwt4 "" "Solo titolo";                  t "artista vuoto" '[ "$(jq -r .artist <<<"$out")" = "" ] && [ "$(jq -r .title <<<"$out")" = "Solo titolo" ]'
probe ewwt5 "Ïñtërnâtiônàl 🎵" "漢字 ☕ \"v\" 'a'"; t "unicode, emoji, virgolette, apici" '[ "$(jq -r .title <<<"$out")" = "漢字 ☕ \"v\" '"'"'a'"'"'" ]'
probe ewwt6 "A" "$(printf 'x%.0s' $(seq 1 300))"; t "titolo di 300 caratteri: testo scorrevole di 22" '[ "$(jq -r ".scroll|length" <<<"$out")" = 22 ]'
probe ewwt7 $'A\x1fB' "Titolo";                t "separatore dentro l'artista: titolo comunque corretto" '[ "$(jq -r .title <<<"$out")" = Titolo ] && [ "$(jq -r .status <<<"$out")" = Playing ]'
exit $res
