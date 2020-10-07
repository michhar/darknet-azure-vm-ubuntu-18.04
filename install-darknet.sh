#!/usr/bin/env bash

# This script is intended as an initialization script used in azuredeploy.json
# See documentation here: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux#template-deployment
# Run with sudo
# comments below:

# Username as argument
adminUser=$1

WD=/home/$adminUser/

# Sleep to let Ubuntu install security updates and other updates
sleep 3m

echo WD is $WD

if [ ! -d $WD ]; then
    echo $WD does not exist - aborting!!
    exit
else
    cd $WD
    echo "Working in $(pwd)" > install-log.txt
fi

# Set so we can write to log
sudo chmod ugo+rw install-log.txt

echo "Installing CUDA and drivers..." >> install-log.txt

# CUDA 11.0 install
# https://www.howtoforge.com/tutorial/how-to-install-nvidia-cuda-on-ubuntu-1804/
sudo wget https://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_450.51.06_linux.run 2>> install-log.txt
sudo chmod +x cuda_11.0.3_450.51.06_linux.run
sudo ./cuda_11.0.3_450.51.06_linux.run --silent --driver --toolkit --samples 2>> install-log.txt

echo "Installing OpenCV..." >> install-log.txt

# Install OpenCV
sudo apt -y update && sudo apt -y install libopencv-dev python3-opencv 2>> install-log.txt

# Clone darknet
cd $WD
git clone https://github.com/AlexeyAB/darknet.git
cd darknet/

# Update variables to enable GPU acceleration for build
sed -i "s/GPU=0/GPU=1/g" Makefile
#sed -i "s/CUDNN=0/CUDNN=1/g" Makefile
#sed -i "s/CUDNN_HALF=0/CUDNN_HALF=1/g" Makefile
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
