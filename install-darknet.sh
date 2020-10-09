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
#sudo apt install -y -q cuda-drivers-455
sudo apt-key adv --fetch-keys  http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
sudo bash -c 'echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list'
sudo bash -c 'echo "deb http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda_learn.list'
sudo apt update
sudo apt install -y -q cuda-drivers cuda-demo-suite-11-0 cuda-runtime-11-0 cuda-11-0
sudo apt install -y -q libcudnn7 libcudnn7-dev

echo "Installing OpenCV..." >> install-log.txt

# Install OpenCV
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

export PATH=/usr/local/cuda-11.0/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-11.0/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

echo "Building darknet..." >> install-log.txt

# Build darknet
sudo make 2>> install-log.txt

# Change permissions to all darknet resources
cd $WD
sudo chmod -R ugo+rw darknet/

echo "Done building darknet!" >> install-log.txt

