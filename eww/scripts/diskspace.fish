#!/usr/bin/fish

set -g units GB MB KB B
set -g vars used total diff

# Prima: last_used partiva da 0, quindi il primissimo "diff" stampato
# all'avvio del daemon era uguale all'intero spazio usato sul disco
# invece che a "nessuna variazione". Qui si fa una lettura iniziale
# "a vuoto" per inizializzare last_used col valore vero prima di
# entrare nel loop che stampa.
set -g last_used (df -x tmpfs -x devtmpfs --block-size=1 | awk 'NR>1 {sum += $3} END {print sum}')

function convert_to_unit -a var
    set -g i 1
    if test $$var != ''
        for exp in (seq 30 -10 10)
            if test (math "abs($$var)") -ge (math 2^$exp)
                set -g $var (math $$var/2^$exp)
                break
            else
                set -g i (math $i+1)
            end
        end
    end

    set -g $var (math "round($$var * 100) / 100")
end

while true

    set -g total (df -x tmpfs -x devtmpfs --block-size=1 | awk 'NR>1 {sum += $2} END {print sum}')
    set -g used (df -x tmpfs -x devtmpfs --block-size=1 | awk 'NR>1 {sum += $3} END {print sum}')
    set -g original_used $used

    set -g diff (math $used - $last_used)

    for var in $vars
        convert_to_unit $var
        set -ga iterations $i
    end

    echo "DISK  $used $units[$iterations[1]] / $total $units[$iterations[2]]  (diff $diff $units[$iterations[3]])"

    set -g last_used $original_used
    set -e iterations
    sleep 1

end
