#!/usr/bin/env bash
# Test dal vivo LEGGERI sulla barra vera: variabili valide e coerenti col sistema,
# un'apertura/chiusura normale del dashboard e del calendario.
E="eww --no-daemonize"; res=0
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 ${3:+[$3]}"; res=1; fi; }
P=~/.config/eww/scripts/popup.sh
$P dashboard; sleep 2   # alcune variabili si aggiornano solo a dashboard aperto
bad=""
for v in clock hypr volume media cava net bt notif weather session brightness profile fans uptime user face wifi-list bt-list activewin public-ip popup reveal-dashboard reveal-calendar reveal-osd power-confirm expand-wifi expand-bt bt-busy osd-kind osd-value osd-muted; do
  val=$(timeout 3 $E get $v 2>&1) || { bad="$bad $v(errore)"; continue; }
  case "$val" in \{*|\[*) echo "$val" | jq -e . >/dev/null 2>&1 || bad="$bad $v(JSON)";; esac
done
t "31 variabili leggibili, JSON valido" '[ -z "$bad" ]' "$bad"
sys_vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d", $2*100+0.5}')
t "volume = sistema" '[ "$($E get volume | jq .volume)" = "$sys_vol" ]'
t "muto = sistema" '[ "$($E get volume | jq .muted)" = "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo true || echo false)" ]'
t "workspace attiva = Hyprland" '[ "$($E get hypr | jq .active)" = "$(hyprctl activeworkspace -j | jq .id)" ]'
t "numero workspace = Hyprland" '[ "$($E get hypr | jq ".workspaces|length")" = "$(hyprctl workspaces -j | jq "[.[]|select(.id>0)]|length")" ]'
t "finestre per workspace = Hyprland" '[ "$($E get hypr | jq -c "[.workspaces[]|.windows]")" = "$(hyprctl workspaces -j | jq -c "[.[]|select(.id>0)]|sort_by(.id)|[.[].windows]")" ]'
t "batteria = sysfs" '[ "$($E get EWW_BATTERY | jq .BAT1.capacity)" = "$(cat /sys/class/power_supply/BAT1/capacity)" ]'
t "SSID = nmcli" '[ "$($E get net | jq -r .wifi.ssid)" = "$(nmcli -t -f ACTIVE,SSID dev wifi | grep -E "^(yes|sì):" | head -1 | cut -d: -f2-)" ]'
t "Bluetooth acceso = bluetoothctl" '[ "$($E get bt | jq .powered)" = "$(bluetoothctl show | grep -q "Powered: yes" && echo true || echo false)" ]'
t "notifiche = swaync" '[ "$($E get notif | jq -r .text)" = "$(swaync-client -c 2>/dev/null)" ]'
t "profilo energetico = powerprofilesctl" '[ "$($E get profile)" = "$(powerprofilesctl get)" ]'
t "luminosità = brightnessctl" '[ "$($E get brightness)" = "$(brightnessctl -m | cut -d, -f4 | tr -d %)" ]'
t "interfaccia principale = ip route" '[ "$($E get net | jq -r .primary)" = "$(ip route get 1.1.1.1 | grep -o "dev [^ ]*" | cut -d" " -f2)" ]'
t "MAC di wlan0 = sysfs" '[ "$($E get net | jq -r ".ifaces[]|select(.name==\"wlan0\").mac")" = "$(cat /sys/class/net/wlan0/address)" ]'
t "utente/iniziale" '[ "$($E get user | jq -r .initial)" = A ]'
t "storico batteria non vuoto" '[ "$($E get session | jq ".battery|length")" -ge 1 ]'
t "meteo su Lugano e valido" '[ "$($E get weather | jq -r .city)" = Lugano ] && [ "$($E get weather | jq .ok)" = true ]'
t "dashboard aperto e visibile" '[ "$($E get reveal-dashboard)" = true ] && $E active-windows | grep -q "^dashboard:"'
$P calendar; sleep 0.5
t "passaggio a calendario" '[ "$($E get reveal-calendar)" = true ] && ! $E active-windows | grep -q "^dashboard:"'
$P close; sleep 0.3
t "chiusura: resta solo la barra" '[ "$($E active-windows | cut -d: -f1 | tr "\n" " ")" = "bar-0 " ]'
exit $res
