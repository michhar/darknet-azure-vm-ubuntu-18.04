#!/usr/bin/env bash

# This script is intended as an initialization script used in azuredeploy.json
# See documentation here: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux#template-deployment
# Run with sudo
# comments below:

# Username as argument
adminUser=$1

WD=/home/$adminUser/

# Sleep to let Ubuntu install security updates and other updates
sleep 1m

echo WD is $WD

if [ ! -d $WD ]; then
    echo $WD does not exist - aborting!!
    exit
else
    cd $WD
    echo "Working in $(pwd)" > install-log.txt
fi

# Set permissions so we can write to log
sudo chmod ugo+rw install-log.txt


export DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Ubuntu 18.04, CUDA 10.1, libcudnn 7.5.1 and NVIDIA 418.67 drivers
# https://askubuntu.com/questions/1077061/how-do-i-install-nvidia-and-cuda-drivers-into-ubuntu
sudo rm /etc/apt/sources.list.d/cuda*
sudo apt remove -y --autoremove nvidia-cuda-toolkit
sudo apt remove -y --autoremove nvidia-*
sudo apt update
sudo add-apt-repository -y ppa:graphics-drivers/ppa
sudo apt update

# Guide: https://www.tensorflow.org/install/gpu 
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-repo-ubuntu1804_10.2.89-1_amd64.deb
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
sudo dpkg -i cuda-repo-ubuntu1804_10.2.89-1_amd64.deb
sudo apt-get update
wget http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/nvidia-machine-learning-repo-ubuntu1804_1.0.0-1_amd64.deb
sudo apt install -y ./nvidia-machine-learning-repo-ubuntu1804_1.0.0-1_amd64.deb
sudo apt update
# Install NVIDIA driver
sudo apt install -y --no-install-recommends nvidia-driver-455
# Reboot. Check that GPUs are visible using the command: nvidia-smi
# Install development and runtime libraries (~4GB)
sudo apt-get install -y --no-install-recommends \
    cuda-10-2 \
    libcudnn7=7.6.5.32-1+cuda10.2  \
    libcudnn7-dev=7.6.5.32-1+cuda10.2;
sudo apt-get install -y --no-install-recommends \
    libnvinfer7=7.0.0-1+cuda10.2 \
    libnvinfer-dev=7.0.0-1+cuda10.2 \
    libnvinfer-plugin7=7.0.0-1+cuda10.2

 echo "export LD_LIBRARY_PATH=/usr/local/cuda-10.2/lib64:${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" >> ~/.bashrc
 echo "export PATH=/usr/local/cuda-10.2/bin${PATH:+:${PATH}}" >> ~/.bashrc
 source ~/.bashrc
 # For tensorflow 2 compatibility with cuda 10.2
 sudo ln -s /usr/local/cuda-10.2/targets/x86_64-linux/lib/libcudart.so.10.2 /usr/lib/x86_64-linux-gnu/libcudart.so.10.1

# Zip stuff and media players (VLC and smplayer)
sudo apt install -y unzip zip vlc smplayer

# Install VOTT labeling tool
wget https://github.com/microsoft/VoTT/releases/download/v2.2.0/vott-2.2.0-linux.snap
sudo apt install -y snap
sudo snap install --dangerous vott-2.2.0-linux.snap

# For X2Go (remote desktop server-side packages)
sudo apt-add-repository -y ppa:x2go/stable
sudo apt update
sudo apt install -y x2goserver x2goserver-xsession x2golxdebindings x2gomatebindings xfce4

# Install nvidia docker
echo "Installing nvidia docker..." >> install-log.txt
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt install -y docker-ce
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add
curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu18.04/nvidia-docker.list -o nvidia-docker.list
cp nvidia-docker.list /etc/apt/sources.list.d/nvidia-docker.list
apt update
apt install -y nvidia-docker2 2>> install-log.txt
pkill -SIGHUP dockerd

# Install OpenCV
echo "Installing OpenCV..." >> install-log.txt
sudo apt update && sudo apt install -y libopencv-dev python3-opencv 2>> install-log.txt

# Clone darknet
cd $WD
git clone https://github.com/AlexeyAB/darknet.git
cd darknet/

# Update variables to enable GPU acceleration for build
sed -i "s/GPU=0/GPU=1/g" Makefile
sed -i "s/CUDNN=0/CUDNN=1/g" Makefile
sed -i "s/CUDNN_HALF=0/CUDNN_HALF=1/g" Makefile
sed -i "s/OPENCV=0/OPENCV=1/g" Makefile
sed -i "s/AVX=0/AVX=1/g" Makefile
sed -i "s/OPENMP=0/OPENMP=1/g" Makefile
sed -i "s/LIBSO=0/LIBSO=1/g" Makefile

# Remove unsupported architectures
sed -i "s/ARCH= -gencode arch=compute_30,code=sm_30 \\\//g" Makefile
sed -i "s/      -gencode arch=compute_35,code=sm_35 \\\/ARCH= -gencode arch=compute_35,code=sm_35 \\\/g" Makefile

# Set NVIDIA compiler to correct path
sed -i "s/NVCC=nvcc/NVCC=\/usr\/local\/cuda\/bin\/nvcc/g" Makefile

# Change permissions on shell scripts
sudo chmod ugo+x *.sh

echo "Building darknet..." >> install-log.txt

# Build darknet
sudo make 2>> install-log.txt

# Change permissions to all darknet resources
cd $WD
sudo chmod -R ugo+rw darknet/

# Install and set up Python
sudo apt install -y python3-pip python3-dev python3-venv libglib2.0-0 libsm6 libxext6 libxrender-dev
cd /usr/local/bin
ln -s /usr/bin/python3 python
pip3 install --upgrade pip

# Git clone TensorFlow Lite darknet conversion project
cd $WD
git clone https://github.com/hunglc007/tensorflow-yolov4-tflite.git
chmod -R ugo+rw tensorflow-yolov4-tflite
cd tensorflow-yolov4-tflite
# Check out specific commit to pin the repo - may update as needed in future
git checkout 9f16748
# Create a python environment
python3 -m venv env
source env/bin/activate
pip install --upgrade pip
pip install --upgrade setuptools
# Install gpu package version of tensorflow because on NC series VMs
sed -i "s/2.3.0rc0/2.3.1/g" requirements-gpu.txt
pip install -r requirements-gpu.txt

# Change owner and group of folders so can access with VoTT
cd $WD
sudo chown -R $adminUser:$adminUser darknet
sudo chown -R $adminUser:$adminUser tensorflow-yolov4-tflite

# Install firefox
sudo apt upgrade && sudo apt install -y firefox

echo "Done building darknet and installing projects!" >> install-log.txt
