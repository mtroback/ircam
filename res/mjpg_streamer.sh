#!/bin/bash
LD_LIBRARY_PATH=. ./mjpg_streamer -o "output_http.so -w ./www -p 80" -i "input_raspicam.so -x 1280 -y 720 -fps 25" &
pid=$!
# When this script exits, kill the mjpg_streamer it started
trap "kill $pid;" EXIT 
wait
