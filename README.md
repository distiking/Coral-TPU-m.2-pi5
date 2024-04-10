# Coral-TPU-m.2-pi5
Coral TPU on raspberry pi 5


Installs and configures your raspberry pi 5 to use google edge m.2 tpu.
It was a nightmare to make this thing working so i wrote this script for myself so i dont have to go thru hell again,
however you find it usefull please help yourself.

WARNING: ( I highly advise to run this script on freshly installed Bookworm 64 as it was tested. It will change kernel page size and install various of packages on your machine,
so I dont want to be responsible for any damages made to your system.)


Important:
this will:
  1. modify various system configurarion files.
  2. instal and compile python 3.9
  3. It will create coral_tpu_venv virtual environment with all necessaries in your home directory.
  4. It will create google-coral and pycoral directories with examples in your home directory.

Instruction:
  1. (Recommended) Install fresh Bookworm 64
  2. Connect to the internet.
  3. Download coral_tpu_install.sh to your home directory.
   sudo chmod +x coral_tpu_install.sh
   ./coral_tpu_install.sh


 The installation takes around 15 - 20 minutes. After that, if it goes well you should see a parrot image and inference times in terminal.
 The system will reboot during installation, then the installation will continue.
 Tested with raspberry pi 5 4gb bookworm 64 2025-03-15
