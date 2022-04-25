#include <iostream>
#include <cstdio>
using namespace std;

int main () {
  freopen("TCP", "r", stdin);
  freopen("result", "w", stdout);
  int n;
  double num;
  char p;
  while (cin >> n) {
    double lsum=0, rsum=0;
    for (int i = 1; i <= n; i++) {
      scanf("%lf%c", &num, &p);
      if (p=='K') num *= 1024;
      else if (p=='M') num *= 1024*1024;
      else if (p=='G') num *= 1024*1024*1024;

      lsum += num;
      rsum += num*num;
    }
    lsum = lsum * lsum;
    rsum = rsum * n;

    printf("%d %.6lf\n", n, lsum/rsum);
  }
  
}