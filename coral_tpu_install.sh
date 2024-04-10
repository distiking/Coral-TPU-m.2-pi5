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
    sudo dtc -I dtb -O dts /boot/firmware/bcm2712-rpi-5-b.dtb -o ~/test.dts
    sudo sed -i '/pcie@110000 {/,/msi-parent = <0x2[fc]>;/{s/<0x2f>/<0x67>/; s/<0x2c>/<0x67>/}' ~/test.dts
    sudo dtc -I dts -O dtb ~/test.dts -o ~/test.dtb
    sudo mv ~/test.dtb /boot/firmware/bcm2712-rpi-5-b.dtb
}

install_packages(){
    sudo apt-get update
    sudo apt-upgrade -y
    sudo apt install -y libcap-dev libatlas-base-dev ffmpeg libopenjp2-7 libedgetpu1-std
    sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev wget libcamera-dev
    sudo apt install -y libkms++-dev libfmt-dev libdrm-dev
    sudo apt-get install -y curl wget
}

install_gasket(){
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
    OUTPUT=$(sudo apt-get install -y gasket-dkms 2>&1)
    EXIT_STATUS=$?
    sudo apt update
    sudo apt install -y libedgetpu1-std
    if [[ $EXIT_STATUS -ne 0 ]]; then
        echo "dkms install failed. Running error script..."
        FILE="/usr/src/gasket-1.0/gasket_core.c"
        LINE_NUMBER=1841
        EXPECTED_VALUE="class_create(driver_desc->module, driver_desc->name);"
        NEW_VALUE="class_create(driver_desc->name);"
        LINE=$(sudo sed "${LINE_NUMBER}q;d" "$FILE")

        if [[ "$LINE" != "$EXPECTED_VALUE" ]]; then
            sudo sed -i "${LINE_NUMBER}s/.*/${NEW_VALUE}/" "$FILE"
            sudo apt-get install -y gasket-dkms
        else
            echo "Installation failed."
            exit 1
        fi
    fi

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
        echo "Error: Failed to install Tflite Runtime package." && sleep 5
        exit 1
    fi

    echo "Cleaning up..."
    rm "$WHEEL_FILE"
    echo "Installing pycoral package..."

    pip3 install "$PACKAGE_URL"
    if [[ $? -eq 0 ]]; then
        echo "pycoral package installed successfully."
    else
        echo "Error: Failed to install pycoral package." && sleep 5
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

    image_path="/$HOME/pycoral/test_data/parrot.jpg"
    git clone https://github.com/google-coral/pycoral.git
    bash examples/install_requirements.sh classify_image.py

    clear

    echo -e "\033[33m<<<<<<<<<<<<   Testing TPU   <<<<<<<<<<<<\033[0m" && sleep
    view_image="python3 examples/classify_image.py \
      --model test_data/mobilenet_v2_1.0_224_inat_bird_quant_edgetpu.tflite \
      --labels test_data/inat_bird_labels.txt \
      --input test_data/parrot.jpg"

    eom "$image_path" &>/dev/null &
    eom_pid=$!
    eval "$view_image"

    if [[ $? -eq 0 ]]; then
        echo "Installation successfull."
    else
        echo "Error: Installation failed." && sleep 5
        exit 1
    fi

    wait $eom_pid
}


script_path="$(realpath "$0")"
autostart_file="$HOME/.config/autostart/coral_setup.desktop"

if [[ "$1" == "--continue" ]]; then
    rm -f "$autostart_file"
    echo -e "\033[33mCoral TPU Setup after reboot...\033[0m"

    output=$(lsmod | grep apex)
    if echo "$output" | grep -q "^apex" && echo "$output" | grep -q "^gasket"; then
        echo -e "\033[33mapex and gasket modules are loaded succesfully.\033[0m"
	echo "$output" && sleep 5
    else
        echo "Error: apex and/or gasket modules are not loaded."
        read -p "Press Enter to exit..."
        exit 1
    fi
    
    install_python
    install_pycoral
    tpu_test
    echo "Coral TPU setup complete!"
    read -p "Press Enter to exit..."
    exit 0
fi

echo "Starting Coral TPU setup..."
install_packages
prepare_config
prepare_device_tree
install_gasket
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
