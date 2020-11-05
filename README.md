# Darknet ML Framework Ubuntu 18.04 Azure VM

## Overview

The intent of this project is to make it easier to deploy an NVIDIA GPU-backed virtual machine in Azure for creating YOLO models.  The VM options have the following AI associated programs installed (mainly) for YOLOv4 experimentation:
- Darknet ML framework (GPU accelerated) for YOLO model training and inference (https://github.com/AlexeyAB/darknet)
- YOLOv4 weights to TensorFlow and TensorFlow Lite converter (https://github.com/hunglc007/tensorflow-yolov4-tflite) (with TensorFlow-GPU installed)
- Visual Object Tagging Tool (VoTT - https://github.com/microsoft/VoTT)
- Python 3
- X2Go server (for remote desktop with X2Go clients)
- VLC (media player)

ML libraries are built for GPU-acceleration with:
- CUDA 10.2
- cuDNN 7
- NVIDIA GPU(s) - type depending on the VM SKU chosen

The deployment happens through a custom Azure Resource Manager (ARM) template.  Regions that this ARM template supports right now:
- canadacentral
- eastus
- southcentralus
- westeurope
- westus2

If you wish to perform your own, custom Darknet experiment, see the notes that utilize this VM here:  https://github.com/michhar/yolov4-darknet-notes.

What gets deployed in Azure along with the VM:
- Public IP address
- Network interface
- Network security group
- Vitural network
- Disk

## ARM Template to deploy a GPU enabled VM with Darknet ML Framework Installed

ARM template to deploy a GPU enabled VM with Darknet pre-installed (via install-darknet.sh)

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmichhar%2Fdarknet-azure-vm-ubuntu-18.04%2Fmaster%2FedgeDeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png" />
</a>

The ARM template visualized for exploration

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fmichhar%2Fdarknet-azure-vm-ubuntu-18.04%2Fmaster%2FedgeDeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png" /></a>

## Azure CLI command to deploy Darknet GPU VM

```bash
az deployment group create \
  --name edgeVm \
  --resource-group replace-with-rg-name \
  --template-uri "https://raw.githubusercontent.com/michhar/darknet-azure-vm-ubuntu-18.04/master/edgeDeploy.json" \
  --parameters dnsLabelPrefix='my-edge-vm1' \
  --parameters adminUsername='azureuser' \
  --parameters authenticationType='password' \
  --parameters adminPasswordOrKey="YOUR_SECRET_PASSWORD"
```

## Testing the installation

### Test the NVIDIA driver and docker

```bash
nvidia-smi
```
 The output should look like this:

```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 450.51.06    Driver Version: 450.51.06    CUDA Version: 11.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla V100-PCIE...  Off  | 00000001:00:00.0 Off |                  Off |
| N/A   30C    P0    38W / 250W |      0MiB / 16160MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```



```bash
sudo docker run --runtime=nvidia --rm nvidia/cuda:11.0-base nvidia-smi
```
The output should look like this (this will pull the docker image down and run nvidia-smi in the container):

```
Unable to find image 'nvidia/cuda:11.0-base' locally
11.0-base: Pulling from nvidia/cuda
54ee1f796a1e: Pull complete 
f7bfea53ad12: Pull complete 
46d371e02073: Pull complete 
b66c17bbf772: Pull complete 
3642f1a6dfb3: Pull complete 
e5ce55b8b4b9: Pull complete 
155bc0332b0a: Pull complete 
Digest: sha256:774ca3d612de15213102c2dbbba55df44dc5cf9870ca2be6c6e9c627fa63d67a
Status: Downloaded newer image for nvidia/cuda:11.0-base
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 450.51.06    Driver Version: 450.51.06    CUDA Version: 11.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla V100-PCIE...  Off  | 00000001:00:00.0 Off |                  Off |
| N/A   31C    P0    37W / 250W |      0MiB / 16160MiB |      4%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

### Test Darknet

You should test darknet.  SSH into the VM.  On Windows, you can do so using a tool such as <a href="https://www.putty.org" target="_blank">PuTTY</a>.

> Note: If you have difficulty logging in (timeout etc.), you may need to navigate to the VM in the Azure Portal and go to Networking under Settings.  There, delete the Cleanuptool-Deny-103 Inbound port rule.  This will allow you to temporarily access the VM with SSH.  You may need to repeat this in the future.

Login in to VM.
```
ssh <username>@<public IP or DNS name>
```

Change directory into the `darknet` project.
```
cd darknet
```

Get the tiny YOLO v4 model.
```
wget https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights
```

Run `darknet` app and test with an image (e.g. `data/giraffe.jpg`).
```
./darknet detector test ./cfg/coco.data ./cfg/yolov4-tiny.cfg ./yolov4-tiny.weights
```

There are test images in the `data` folder under the `darknet` repository to try.  The image is saved each time as `predictions.jpg` and may be downloaded with the Unix `scp` command or <a href="https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html" target="_blank">Windows SCP client</a>.

```
scp <username>@<public IP or DNS name>:~/darknet/predictions.jpg .
```

Note:  you could also use a remote desktop session as in with X2Go client for Windows or Mac to run the Darknet detector test and visualize the results.

## Troubleshooting

To investigate what occurred during deployment the install logs can be found in the /home/<adminUsername> directory. 

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
