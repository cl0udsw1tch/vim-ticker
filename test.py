import sys
import random
import time
 
r=[100*i for i in range(1,len(sys.argv))]
while True:
    for i,ticker in enumerate(sys.argv[1:]):
        r[i] +=  random.randint(-10,10) 
        print(ticker + " " + str(r[i]), flush=True)
    time.sleep(5)
