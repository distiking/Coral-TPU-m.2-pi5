Coral TPU on Raspberry Pi 5

This script installs and configures your Raspberry Pi 5 to use the Google Edge M.2 TPU. The process of setting up the TPU can be challenging, so I wrote this script to simplify the installation and save time in the future. If you find it useful, please feel free to use it.

WARNING: I highly advise running this script on a freshly installed Bookworm 64, as it has been tested on this configuration. The script will change the kernel page size and install various packages on your machine, so I don't want to be responsible for any damages made to your system.
Important

This script will:

    Modify various system configuration files.
    Install and compile Python 3.9.
    Create a coral_tpu_venv virtual environment with all necessary packages in your home directory.
    Create google-coral and pycoral directories with examples in your home directory.

Instructions

    (Recommended) Install a fresh Bookworm 64 on your Raspberry Pi 5.
    Connect your Raspberry Pi to the internet.
    Download coral_tpu_install.sh to your home directory.
    Run the following commands:

    sudo chmod +x coral_tpu_install.sh
    ./coral_tpu_install.sh
    
Option 1 for full installation

The installation process takes around 15-20 minutes. If everything goes well, you should see a parrot image and inference times in the terminal. The system will reboot during the installation, and then the installation will continue.

Tested with:

    Raspberry Pi 5 4GB
    Bookworm 64 (2024-03-15)

Last tested: 14/04/2024
