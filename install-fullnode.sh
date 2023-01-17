#!/bin/bash
if [ "$(id -u)" -nq 0 ]; then
  echo "This script must not be run as root" >&2
  exit 1
fi
apt update -y
echo "Enter your name MONIKER:"
read MONIKER
echo "Install go 1.19.1"
ver="1.19.1"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"

cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF

source $HOME/.profile
go version

apt-get install build-essential -y && sudo apt-get install jq curl tar wget clang pkg-config libssl-dev git make ncdu -y

echo "Install celestia app"
pkill celestia
cd $HOME
rm -rf celestia-app
git clone https://github.com/celestiaorg/celestia-app.git
cd celestia-app/
APP_VERSION=v0.11.0
git checkout tags/$APP_VERSION -b $APP_VERSION
make install
celestia-appd version

echo "Install celestia node"
cd $HOME
rm -rf celestia-node
git clone https://github.com/celestiaorg/celestia-node.git
cd celestia-node/
git checkout tags/v0.6.1
make install
make cel-key

echo "Install celestia network"
cd $HOME
rm -rf networks
git clone https://github.com/celestiaorg/networks.git

celestia-appd init $MONIKER --chain-id mocha
cp $HOME/networks/mocha/genesis.json $HOME/.celestia-app/config

SEEDS="8084e73b70dbe7fba3602be586de45a516012e6f@144.76.112.238:26656"
PEERS="eaa763cde89fcf5a8fe44274a5ee3ce24bce2c5b@64.227.18.169:26656,0d0f0e4a149b50a96207523a5408611dae2796b6@198.199.82.109:26656,c2870ce12cfb08c4ff66c9ad7c49533d2bd8d412@178.170.47.171:26656"
sed -i -e 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.celestia-app/config/config.toml
sed -i -e "s/^seed_mode *=.*/seed_mode = \"$SEED_MODE\"/" $HOME/.celestia-app/config/config.toml

PRUNING="custom"
PRUNING_KEEP_RECENT="100"
PRUNING_INTERVAL="10"

sed -i -e "s/^pruning *=.*/pruning = \"$PRUNING\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \
\"$PRUNING_KEEP_RECENT\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \
\"$PRUNING_INTERVAL\"/" $HOME/.celestia-app/config/app.toml


cd $HOME
rm -rf ~/.celestia-app/data
mkdir -p ~/.celestia-app/data
SNAP_NAME=$(curl -s https://snaps.qubelabs.io/celestia/ | \
    egrep -o ">mocha.*tar" | tr -d ">")
wget -O - https://snaps.qubelabs.io/celestia/${SNAP_NAME} | tar xf - \
    -C ~/.celestia-app/data/

tee <<EOF >/dev/null /etc/systemd/system/celestia-appd.service
[Unit]
Description=celestia-appd Cosmos daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$HOME/go/bin/celestia-appd start
Restart=on-failure
RestartSec=3
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF

systemctl enable celestia-appd
systemctl start celestia-appd

echo "Check status:  systemctl status celestia-appd "
echo "Check sync:  curl -s localhost:26657/status | jq .result | jq .sync_info "
