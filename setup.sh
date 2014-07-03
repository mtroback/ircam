#!/bin/bash -x
# Part of https://github.com/mtroback/ircam
#
# See LICENSE file for copyright and license details

# This script
# 1. Sets up the camera module
# 2. Edits the hostname according to the users choice
# 3. Installs mjpg-streamer from https://github.com/jacksonliam/mjpg-streamer
# 4. Sets up scripts to automaticly start and stream at port 80
# 5. Adds a script which listens for a short circuit on gpio 26 and shuts down
#    on such event
# 6. Reboots


# The following code has been copied from
# https://github.com/asb/raspi-config/blob/master/raspi-config

do_change_hostname() {
  whiptail --msgbox "\
Please note: RFCs mandate that a hostname's labels \
may contain only the ASCII letters 'a' through 'z' (case-insensitive), 
the digits '0' through '9', and the hyphen.
Hostname labels cannot begin or end with a hyphen. 
No other symbols, punctuation characters, or blank spaces are permitted.\
" 20 70 1

  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

disable_raspi_config_at_boot() {
  if [ -e /etc/profile.d/raspi-config.sh ]; then
    rm -f /etc/profile.d/raspi-config.sh
    sed -i /etc/inittab \
      -e "s/^#\(.*\)#\s*RPICFG_TO_ENABLE\s*/\1/" \
      -e "/#\s*RPICFG_TO_DISABLE/d"
    telinit q
  fi
}

set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end

if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

get_config_var() {
  lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
  local val = line:match("^#?%s*"..key.."=(.*)$")
  if (val ~= nil) then
    print(val)
    break
  end
end
EOF
}

set_camera() {
  # Stop if /boot is not a mountpoint
  if ! mountpoint -q /boot; then
    return 1
  fi

  [ -e /boot/config.txt ] || touch /boot/config.txt

  set_config_var start_x 1 /boot/config.txt
  CUR_GPU_MEM=$(get_config_var gpu_mem /boot/config.txt)
  if [ -z "$CUR_GPU_MEM" ] || [ "$CUR_GPU_MEM" -lt 128 ]; then
    set_config_var gpu_mem 128 /boot/config.txt
  fi
  sed /boot/config.txt -i -e "s/^startx/#startx/"
  sed /boot/config.txt -i -e "s/^fixup_file/#fixup_file/"

}

if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo ./setup.sh'\n"
  exit 1
fi

# --- End of copied code ---

# Get script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Do raspi-config stuff
set_camera
do_change_hostname

# Install required packages
aptitude install libjpeg8-dev cmake

# Build mjpg-streamer (as user pi)
su -c "cd && " \
"git clone https://github.com/jacksonliam/mjpg-streamer.git && " \
"cd mjpg-streamer/mjpg-streamer-experimental && " \
"make && echo Done building mjpg-streamer" pi

# Move the simple stream page to index.html
cd mjpg-streamer/mjpg-streamer-experimental
mv www/index.html www/index.html.old
cp www/stream_simple.html www/index.html

# Install script files
cp -a $DIR/../res/mjpg-streamer.init /etc/init.d/mjpg-streamer
chmod +x /etc/init.d/mjpg-streamer
cp -a $DIR/../res/mjpg_streamer.sh /home/pi
chmod a+rwx /home/pi/mjpg_streamer.sh
update-rc.d mjpg-streamer defaults

# Copy the key press script and make it start at boot 
cp -a $DIR/../res/shutdown_button.py /home/pi
awk '$0 == "exit 0" && c == 0 {c = 1; print "# Poll shutdown button\n/home/pi/shutdown_button.py &\n"}; {print}'  /etc/rc.local > /etc/rc.local

# TODO set up tmpfs folders for common write folder to save SD-writes

# Done, restart
sync
restart