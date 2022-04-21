import matplotlib.pyplot as plt
import pandas as pd

fileName = "cubic_vs_bbr_nofair"
y1_field = "CUBIC"
y2_field = "BBR"

data=pd.read_csv(fileName + ".csv")

X = data["Interval start"]
Y1 = data[y1_field]
Y2 = data[y2_field]

fig = plt.figure()
a1 = fig.add_axes([0.15,0.1,0.8,0.8])

a1.plot(X,Y1/1024,color="blue", linewidth=2.5, linestyle="-", label=y1_field)
a1.plot(X,Y2/1024,color="red", linewidth=2.5, linestyle="-", label=y2_field)

a1.set_xlabel('Time(s)')
a1.set_ylabel('GoodPut(Mbps)')

# a1.set_xlim(0, 100)
# a1.set_ylim(0, 15)

plt.legend(loc='upper left')

plt.savefig('./' + fileName + '.jpg')
plt.show()