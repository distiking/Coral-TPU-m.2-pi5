#!/bin/bash

prepare_config(){
    FILE="/boot/firmware/config.txt"
    LINE="kernel=kernel8.img"
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" | sudo tee -a "$FILE" > /dev/null
    fi
    LINE="dtparam=pciex1"
    if ! grep -Fxq "$LINE" "$FILE"; then
        echo "$LINE" | sudo tee -a "$FILE" > /dev/null
    fi
}

prepare_device_tree(){
    sudo cp /boot/firmware/bcm2712-rpi-5-b.dtb /boot/firmware/bcm2712-rpi-5-b.dtb.bak
    sudo dtc -I dtb -O dts /boot/firmware/bcm2712-rpi-5-b.dtb -o ~/dev_tree.dts
    sudo sed -i '/pcie@110000 {/,/msi-parent = <0x2[fc]>;/{s/<0x2f>/<0x67>/; s/<0x2c>/<0x67>/}' ~/dev_tree.dts
    sudo dtc -I dts -O dtb ~/dev_tree.dts -o ~/dev_tree.dtb
    sudo mv ~/dev_tree.dtb /boot/firmware/bcm2712-rpi-5-b.dtb
}

install_packages(){
    sudo apt-get update
    sudo apt-upgrade -y
    sudo apt install -y libcap-dev libatlas-base-dev ffmpeg libopenjp2-7 libedgetpu1-std curl wget
    sudo apt install -y build-essential zlib1g-dev libncurses5-dev libncursesw5-dev libgdbm-dev libsqlite3-dev liblzma-dev libffi-dev tk-dev libjpeg-dev libtiff-dev libwebp-dev libbz2-dev libnss3-dev libssl-dev libreadline-dev libffi-dev wget libcamera-dev
    sudo apt install -y libkms++-dev libfmt-dev libdrm-dev libjpeg-dev libtiff-dev libwebp-dev
}

install_driver(){

    echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo apt update
    OUTPUT=$(sudo apt-get install -y gasket-dkms libedgetpu1-std 2>&1)
    EXIT_STATUS=$?
    
    if [[ $EXIT_STATUS -ne 0 ]]; then
        echo "\033[33mdkms installation failed. Running error script...\033[0m"
        FILE="/usr/src/gasket-1.0/gasket_core.c"
        LINE_NUMBER=1841
        EXPECTED_VALUE="class_create(driver_desc->module, driver_desc->name);"
        NEW_VALUE="class_create(driver_desc->name);"
        LINE=$(sudo sed "${LINE_NUMBER}q;d" "$FILE")

        if [[ "$LINE" != "$EXPECTED_VALUE" ]]; then
            sudo sed -i "${LINE_NUMBER}s/.*/${NEW_VALUE}/" "$FILE"
            sudo apt-get install -y gasket-dkms
            OUTPUT=$(sudo apt-get install -y gasket-dkms 2>&1)
            EXIT_STATUS=$?

            if [[ $EXIT_STATUS -ne 0 ]]; then
                read -p "Installation failed."
                exit 1
            fi
	else
            read -p  "Failed to install driver."
            exit 1
        fi
    fi
    echo " Driver installation complete"
    sudo sh -c "echo 'SUBSYSTEM==\"apex\", MODE=\"0660\", GROUP=\"apex\"' >> /etc/udev/rules.d/65-apex.rules"
    sudo groupadd apex
    sudo adduser $USER apex
}

install_python(){
    sudo apt update
    cd ~
    wget https://www.python.org/ftp/python/3.9.13/Python-3.9.13.tgz
    tar -xf Python-3.9.13.tgz
    rm -f Python-3.9.13.tgz
    cd Python-3.9.13
    ./configure --enable-optimizations
    make -j 4
    sudo ln -s /usr/local/bin/python3.9 /usr/local/bin/python3.9
    sudo make altinstall
    cd ~
    python3.9 -m venv --system-site-packages coral_tpu_venv
    source coral_tpu_venv/bin/activate
    pip3 install opencv-contrib-python
}

install_pycoral(){
    cd ~
	source coral_tpu_venv/bin/activate
    if [[ $(getconf LONG_BIT) == 64 ]]; then
        WHEEL_URL="https://github.com/google-coral/pycoral/releases/download/v2.0.0/tflite_runtime-2.5.0.post1-cp39-cp39-linux_aarch64.whl"
        PACKAGE_URL="https://github.com/google-coral/pycoral/releases/download/v2.0.0/pycoral-2.0.0-cp39-cp39-linux_aarch64.whl"
    else
        WHEEL_URL="https://github.com/google-coral/pycoral/releases/download/v2.0.0/tflite_runtime-2.5.0.post1-cp39-cp39-linux_armv7l.whl"
        PACKAGE_URL="https://github.com/google-coral/pycoral/releases/download/v2.0.0/pycoral-2.0.0-cp39-cp39-linux_armv7l.whl"
    fi

    echo "Downloading wheel file..."
    wget "$WHEEL_URL"
    WHEEL_FILE=$(basename "$WHEEL_URL")
    echo "Installing wheel file..."
    pip3 install "$WHEEL_FILE"

    if [[ $? -eq 0 ]]; then
        echo "Tflite Runtime installed successfully."
    else
        read -p "Error: Failed to install Tflite Runtime package."
        exit 1
    fi

    echo "Cleaning up..."
    rm "$WHEEL_FILE"
    echo "Installing pycoral package..."

    pip3 install "$PACKAGE_URL"
    if [[ $? -eq 0 ]]; then
        echo "Pycoral package installed successfully."
    else
        read -p  "Error: Failed to install pycoral package."
        exit 1
    fi

    echo "Installing Google Coral Examples"
    mkdir google-coral && cd google-coral
    git clone https://github.com/google-coral/examples-camera --depth 1
    cd examples-camera
    sh download_models.sh
}

tpu_test(){
    cd ~
    source coral_tpu_venv/bin/activate
    image_path="$HOME/coral/pycoral/test_data/parrot.jpg"

    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "You are currently in a virtual environment: $VIRTUAL_ENV"

        if test -e "$image_path"; then
            echo "Coral examples were installed."
        else
            echo "File does not exist"
            mkdir -p "$HOME/coral"
            cd "$HOME/coral"
            git clone https://github.com/google-coral/pycoral.git
            bash pycoral/examples/install_requirements.sh classify_image.py
        fi
    else
		clear
        echo -e "\033[33mYou are not in virtual environment.\033[0m"
        return
    fi

    clear
    cd ~
    echo -e "\033[33m<<<<<<<<<<<<   Testing TPU   <<<<<<<<<<<<\033[0m" && sleep 1
    test_cmd="python3 coral/pycoral/examples/classify_image.py \
      --model coral/pycoral/test_data/mobilenet_v2_1.0_224_inat_bird_quant_edgetpu.tflite \
      --labels coral/pycoral/test_data/inat_bird_labels.txt \
      --input coral/pycoral/test_data/parrot.jpg"
    
    eval "$test_cmd"
    if [[ $? -eq 0 ]]; then
        
        eom "$image_path" &>/dev/null &
		eom_pid=$!
		echo "Installation successfull."
        read -p "Press Enter to exit..."
        kill $eom_pid
        exit 0
    else
        read -p  "Error: Installation failed."
        exit 1
    fi
}


script_path="$(realpath "$0")"
autostart_file="$HOME/.config/autostart/coral_setup.desktop"

display_menu() {
    echo "Coral TPU Setup Menu:"
    echo "1. Run the complete setup script"
    echo "2. Prepare config only"
    echo "3. Prepare device tree only"
    echo "4. Install driver (gasket) only"
    echo "5. Install packages only"
    echo "6. Install Python only"
    echo "7. Install PyCoral only"
    echo "8. Run TPU test only"
    echo "9. Exit"
    read -p "Enter your choice (1-9): " choice
    echo
}    

if [[ "$1" == "--continue" ]]; then
    rm -f "$autostart_file"
    echo -e "\033[33mCoral TPU Setup after reboot. Please wait...\033[0m" && sleep 10
    sudo modprobe apex
    output=$(lsmod | grep apex)

    if echo "$output" | grep -q "^apex" && echo "$output" | grep -q "^gasket"; then
        clear
        echo -e "\033[33mapex and gasket modules are loaded successfully.\033[0m"
        echo "$output" && sleep 5
    else
        read -p  "Error: apex and/or gasket modules are not loaded."
        exit 1
    fi
    install_packages
    install_python
    install_pycoral
    tpu_test

fi

while true; do
    display_menu
    case $choice in
        1)
            echo "Running the complete setup script..."
            prepare_config
            prepare_device_tree
            install_driver
            echo "Pre-reboot actions complete. Rebooting..."
            mkdir -p "$(dirname "$autostart_file")"
            cat > "$autostart_file" << EOL
[Desktop Entry]
Type=Application
Name=Coral TPU Setup
Exec=lxterminal -e "$script_path" --continue
Terminal=false
EOL
            echo -e "\033[33mWarning: The system will reboot in 5 seconds and the installation will continue!\033[0m" && sleep 5 && sudo reboot
            ;;
        2)
            echo "Preparing config..."
            prepare_config
            ;;
        3)
            echo "Preparing device tree..."
            prepare_device_tree
            ;;
        4)
            echo "Installing driver (gasket)..."
            install_driver
            ;;
        5)
            echo "Installing packages..."
            install_packages
            ;;
        6)
            echo "Installing Python..."
            install_python
            ;;
        7)
            echo "Installing PyCoral..."
            install_pycoral
            ;;
        8)
            echo "Running TPU test..."
            tpu_test
            ;;
        9)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter a number between 1 and 9."
            ;;
    esac
done
