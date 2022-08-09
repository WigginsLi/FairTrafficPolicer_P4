#!/bin/bash
python3 cm-sketch-controller.py --option "reset"
python3 cm-sketch-controller.py --option "set_hashes"

mod=8192
echo "$mod" > "$mod result.csv"
for ((i=1000; i<=5000; i+=1000))
do
  mx h1 python3 send.py --n-pkt $((4*$i)) --n-hh 20 --n-sfw $(($i-20)) --p-hh 0.10
  python3 cm-sketch-controller.py --eps 0.001 --n $((4*$i)) --mod $mod --option decode >> "$mod result.csv"
done

