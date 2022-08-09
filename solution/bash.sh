#!/bin/bash

python3 cm-sketch-controller.py --option "reset"
python3 cm-sketch-controller.py --option "set_hashes"

pre="10.0.1."
S="21"

./lanchIperfS.sh

echo "Are you ready? press enter to continue."

read en

mx h1 sudo sysctl net.ipv4.tcp_congestion_control=cubic 
mx h2 sudo sysctl net.ipv4.tcp_congestion_control=cubic
mx h3 sudo sysctl net.ipv4.tcp_congestion_control=bbr

mx h1 iperf -c $pre$S -t 100 &
sleep 20
mx h2 iperf -c $pre$S -t 60 &
sleep 20
mx h3 iperf -c $pre$S -t 20 

wait
sleep 10
mx "h$S" pkill iperf
wait $!
exit 1