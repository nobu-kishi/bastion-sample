#!/bin/bash

# dockerのインストールと設定
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker azureuser
sudo systemctl enable docker

# Azure CLI関連ツールのインストール
# https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli-linux?pivots=apt
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
  gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

az_dist=$(lsb_release -cs)
echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: $az_dist
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

# Azure CLIのインストール
sudo apt-get update
sudo apt-get install -y azure-cli