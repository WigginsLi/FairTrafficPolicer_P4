#!/bin/bash

echo "" > TCP  

pre="10.0.1."
S="21"

./lanchIperfS.sh

for TCP_NUM in {1..20..1}
do
  echo $TCP_NUM >> TCP 
  for ((host=1; host<=$TCP_NUM; host++))
  do
    rand=$RANDOM
    if [ $(($rand%2)) -eq 0 ];
    then
      mx "h$host" sudo sysctl net.ipv4.tcp_congestion_control=cubic >> iperfS_OUT&
    else
      mx "h$host" sudo sysctl net.ipv4.tcp_congestion_control=bbr >> iperfS_OUT&
    fi
  done
  wait

  for ((host=1; host<=$TCP_NUM; host++))
  do
    mx "h$host" iperf -c $pre$S | grep sec | awk '{print $5$6}' | tr "Bytes" " ">> TCP &
  done
  wait
  sleep 30
done 

sleep 10
mx "h$S" pkill iperf
wait $!
exit 1