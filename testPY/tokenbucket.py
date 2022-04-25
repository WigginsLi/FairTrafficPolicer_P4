#!/usr/bin/python

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import CPULimitedHost
from mininet.link import TCLink
from mininet.util import dumpNodeConnections
from mininet.log import setLogLevel
from mininet.node import OVSController
from mininet.cli import CLI
import time
import os

myBandwidth = 10    # bandwidth of link ink Mbps
myDelay = ['10ms']    # latency of each bottleneck link
myQueueSize = 5  # buffer size in packets
myLossPercentage = 0   # random loss on bottleneck links

#
#           h2      h4       
#           |       |        
#           |       |        
#           |       |        
#   h1 ---- S1 ---- S2 ----- h6 
#           |   10ms |    
#           |        |        
#           |        |        
#           h3       h5      
#
#

class ParkingLotTopo( Topo ):
    "Three switches connected to hosts. n is number of hosts connected to switch 1 and 3"
    def build( self, n=2 ):
        switch1 = self.addSwitch('s1')
        switch2 = self.addSwitch('s2')
        
        # Setting the bottleneck link parameters (htb -> Hierarchical token bucket rate limiting)
        self.addLink( switch1, switch2, 
            bw=myBandwidth, 
            delay=myDelay[0], 
            loss=myLossPercentage, 
            use_tfb=True,
            max_queue_size=myQueueSize,
            )

        for h in range(21):
            host = self.addHost('h%s' % (h + 1))
            if h+1 <= 20:
                self.addLink(host, switch1) # one host to switch 1 (h1, h2, h3)
            elif h+1 <= 21:
                self.addLink(host, switch2) # n hosts to switch 2 (h4, h5)


def perfTest():
    "Create network and run simple performance test"
    topo = ParkingLotTopo(n=2)
    net = Mininet( topo=topo,
                   host=CPULimitedHost, link=TCLink, controller = OVSController)
    net.start()
    print("Dumping host connections")
    dumpNodeConnections( net.hosts )
    print("Testing network connectivity")
    net.pingAll()
    CLI( net )  # start mininet interface
    net.stop() # exit mininet

if __name__ == '__main__':
    os.system("sudo mn -c") # clear all previous mininet config
    os.system("killall /usr/bin/ovs-testcontroller")
    setLogLevel( 'info' )
    print("\n\n\n ------Start Mininet ----- \n\n")
    perfTest()
    print("\n\n\n ------End Mininet ----- \n\n")
