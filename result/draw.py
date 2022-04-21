import matplotlib.pyplot as plt
import pandas as pd

fileName = "bbr_vs_bbr_nofair"
y1_field = "BBR_1"
y2_field = "BBR_2"

data=pd.read_csv("./csv/" + fileName + ".csv")

X = data["Interval start"]
Y1 = data[y1_field]
Y2 = data[y2_field]

fig = plt.figure()
a1 = fig.add_axes([0.15,0.1,0.8,0.8])

a1.plot(X,Y1/1024,"b.-", label=y1_field)
a1.plot(X,Y2/1024,"r.-", label=y2_field)

a1.set_xlabel('Time(s)')
a1.set_ylabel('GoodPut(Mbps)')

a1.grid(color='b', ls = '-.', lw = 0.25)

# a1.set_xlim(0, 100)
# a1.set_ylim(0, 15)

plt.legend(loc='best')

plt.savefig('./image/' + fileName + '.jpg')
plt.show()