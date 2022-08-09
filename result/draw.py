import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

fileName1 = "1024 result"
fileName2 = "2048 result"
fileName3 = "4096 result"
fileName4 = "8192 result"
y1_field = "4x1024"
y2_field = "4x2048"
y3_field = "4x4096"
y4_field = "4x8192"
# y3_field = "BBR"

data1=pd.read_csv("./csv/" + fileName1 + ".csv")
data2=pd.read_csv("./csv/" + fileName2 + ".csv")
data3=pd.read_csv("./csv/" + fileName3 + ".csv")
data4=pd.read_csv("./csv/" + fileName4 + ".csv")

X = [1000, 2000, 3000, 4000, 5000]
Y1 = data1[y1_field]
Y2 = data2[y2_field]
Y3 = data3[y3_field]
Y4 = data4[y4_field]
# Y3 = data[y3_field]

fig = plt.figure()
a1 = fig.add_axes([0.15,0.1,0.8,0.8])

# a1.plot(X,Y1*100,"ro-", label=y1_field)
# a1.plot(X,Y2*100,"bv-", label=y2_field)
a1.plot(X,Y3*100,"gs-", label=y3_field)
a1.plot(X,Y4*100,"y*-", label=y4_field)
# a1.plot(X,Y3/1024,"y.-", label=y3_field)

a1.set_xlabel('Num of flows')
a1.set_ylabel("Mean Error(%)")

a1.grid(color='b', ls = '-.', lw = 0.25)

# a1.set_xticks(range(1, 21, 1))
# a1.set_yticks(np.arange(0, 100, 5))

plt.legend(loc='best')

plt.savefig('./image/' + '4096 vs 8192' + '.jpg')
plt.show()