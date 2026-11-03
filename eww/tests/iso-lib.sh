#!/usr/bin/env bash
# Istanza eww ISOLATA per test pesanti (config e socket separati dalla barra vera).
# Uso: source iso-lib.sh; iso_setup <n_widget>; ...; iso_cleanup
ISO=${ISO:-/tmp/eww-iso-test}
iso_setup() {
  local n=${1:-1500}
  rm -rf "$ISO"; mkdir -p "$ISO"
  python3 - "$ISO" "$n" <<'PY'
import sys
d, n = sys.argv[1], int(sys.argv[2])
items = " ".join(f'(box (label :text "{i} ${{x}}") (progress :value {i%100}))' for i in range(n))
geo = '(geometry :x "0" :y "0" :width "1px" :height "1px" :anchor "bottom left")'
open(f"{d}/eww.yuck", "w").write(f'''(defvar x 0)
(defwindow heavy :monitor 0 :geometry {geo} :stacking "bottom" :exclusive false :focusable false
  (scroll :height 1 (box :orientation "v" {items})))
(defwindow light :monitor 0 :geometry {geo} :stacking "bottom" :exclusive false :focusable false (label :text x))
(defwindow light2 :monitor 0 :geometry {geo} :stacking "bottom" :exclusive false :focusable false (label :text x))
''')
open(f"{d}/eww.scss", "w").write("window, * { background-color: transparent; color: transparent; }\n")
PY
  timeout 10 eww -c "$ISO" daemon >/dev/null 2>&1; sleep 1.5
}
# PID dei processi eww della SOLA istanza isolata (confronto esatto su /proc/PID/cmdline)
iso_pids() {
  local p
  for p in $(pgrep -x eww); do
    tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q -- "-c $ISO " && echo $p
  done
}
# daemon = processi eww dell'istanza con un socket unix in ascolto
iso_daemons() {
  local p n=0
  for p in $(iso_pids); do
    ss -xlp 2>/dev/null | grep -q "pid=$p," && n=$((n+1))
  done; echo $n
}
iso_cleanup() {
  local p; for p in $(iso_pids); do kill $p 2>/dev/null; done; sleep 0.5
  for p in $(iso_pids); do kill -9 $p 2>/dev/null; done; rm -rf "$ISO"
}
