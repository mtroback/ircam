ircam
=====

The purpose of this project is to simplify the setup of an autostarted mjpg-stream. Simply clone this project to your pi home folder (git clone git://github.com/mtroback/ircam), "cd ircam", "sudo ./setup.sh" and then follow the instructions.

This will download, build mjpg-streamer and adds script to /etc/init.d for autostart functionality. It also adds a python script which listen for a shutdown button connected between I/O pin 25 and 26.
