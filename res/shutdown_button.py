#!/usr/bin/env python
import os
import time
from RPi import GPIO
GPIO.setmode(GPIO.BOARD)
GPIO.setup(26, GPIO.IN, pull_up_down=GPIO.PUD_UP)

GPIO.wait_for_edge(26, GPIO.FALLING)
os.system("shutdown -h now")
print "Shutdown..."
#i = 0
#while i < 20:
#    print GPIO.input(26)
#    i=i+1
#    time.sleep(1)


GPIO.cleanup()
