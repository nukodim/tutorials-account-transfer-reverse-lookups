#!/bin/bash
# wget -q -O anoma.sh https://api.nodes.guru/anoma.sh && chmod +x anoma.sh && sudo /bin/bash anoma.sh



exists()
{
  command -v "$1" >/dev/null 2>&1
}
if exists curl; then
	echo ''
else
  sudo apt install curl -y < "/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
    . $HOME/.bash_profile
fi
curl -s https://api.nodes.guru/logo.sh | bash

function setupVars {
	# if [ ! $ANOMA_NODENAME ]; then
		# read -p "Enter your node name: " ANOMA_NODENAME_ORIGINAL
		# echo 'export ANOMA_NODENAME="'${ANOMA_NODENAME_ORIGINAL}' | NodesGuru"' >> $HOME/.bash_profile
		# echo 'export ANOMA_NODENAME_ORIGINAL='${ANOMA_NODENAME_ORIGINAL} >> $HOME/.bash_profile
	# fi
	echo 'export PATH=$PATH:$HOME/anoma/target/release:$HOME/anoma-v0.2.0-Linux-x86_64' >> $HOME/.bash_profile
	# echo -e '\n\e[42mYour node name:' $ANOMA_NODENAME_ORIGINAL '\e[0m\n'
	. $HOME/.bash_profile
	sleep 1
}

function setupSwap {
	echo -e '\n\e[42mSet up swapfile\e[0m\n'
	curl -s https://api.nodes.guru/swap4.sh | bash
}

function installRust {
	echo -e '\n\e[42mInstall Rust\e[0m\n' && sleep 1
	# sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
	curl https://getsubstrate.io -sSf | bash -s -- --fast 
	. $HOME/.cargo/env
}

function installGo {
	echo -e '\n\e[42mInstall Go\e[0m\n' && sleep 1
	cd $HOME
	wget -O go1.17.1.linux-amd64.tar.gz https://golang.org/dl/go1.17.linux-amd64.tar.gz
	rm -rf /usr/local/go && tar -C /usr/local -xzf go1.17.1.linux-amd64.tar.gz && rm go1.17.1.linux-amd64.tar.gz
	echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
	echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
	echo 'export GO111MODULE=on' >> $HOME/.bash_profile
	echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
	go version
}


function installDeps {
	echo -e '\n\e[42mPreparing to install\e[0m\n' && sleep 1
	cd $HOME
	sudo apt update
	sudo apt install make clang pkg-config libssl-dev build-essential git jq llvm libudev-dev ntp -y < "/dev/null"
	installRust
	installGo
}

function installSoftware {
	echo -e '\n\e[42mInstall software\e[0m\n' && sleep 1
	cd $HOME
	# wget -q -O $HOME/anoma.tar.gz https://github.com/anoma/anoma/releases/download/v0.2.0/anoma-v0.2.0-Linux-x86_64.tar.gz
	# tar -xzf $HOME/anoma.tar.gz
	
	git clone https://github.com/anoma/anoma.git
	cd anoma
	git checkout v0.2.0
	cp -a $HOME/anoma/wasm $HOME/wasm
	make install
	
	anomac utils join-network --chain-id=anoma-feigenbaum-0.ebb9e9f9013
}

function updateSoftware {
	echo -e '\n\e[42mUpdate software\e[0m\n' && sleep 1
	sudo systemctl stop anomad
	cd $HOME
	git clone https://github.com/anoma/anoma.git
	cd $HOME/anoma
	git reset --hard
	git pull origin master
	make install
}

function installService {
echo -e '\n\e[42mCreating a service\e[0m\n'

echo -e '\n\e[42mJoin network...\e[0m\n'
cd $HOME
anomac utils join-network --chain-id=anoma-feigenbaum-0.ebb9e9f9013

sudo tee <<EOF >/dev/null $HOME/anomad.service
[Unit]
Description=Anoma Ledger Node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME
#ExecStart=$(which anoma) --wasm-dir $HOME/anoma/wasm/ --base-dir $HOME/.anoma/ node ledger
ExecStart=$(which anoman) --wasm-dir $HOME/wasm/ --base-dir $HOME/.anoma/ ledger
Restart=always
RestartSec=3
LimitNOFILE=65535
Environment=RUST_BACKTRACE=1
Environment=RUST_BACKTRACE=full
[Install]
WantedBy=multi-user.target
EOF

sudo mv $HOME/anomad.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
. $HOME/.bash_profile
checkService
}

function checkService {
sudo systemctl enable anomad
sudo systemctl restart anomad
echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service anomad status | grep active` =~ "running" ]]; then
  echo -e "Your Anoma Ledger node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice anomad status\e[0m or \e[7mjournalctl -u anomad -f\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your Anoma Ledger node \e[31mwas not installed correctly\e[39m, retrying...."
  installService
fi
}

function deleteAnoma {
	sudo systemctl disable anoma-gossip anomad
	sudo systemctl stop anoma-gossip anomad
}

PS3='Please enter your choice (input your option number and press enter): '
options=("Install" "Update" "Disable" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install")
            echo -e '\n\e[42mYou choose install...\e[0m\n' && sleep 1
			setupVars
			setupSwap
			installDeps
			installSoftware
			checkService
			break
            ;;
        "Update")
            echo -e '\n\e[33mYou choose update...\e[0m\n' && sleep 1
			updateSoftware
			checkService
			echo -e '\n\e[33mYour node was updated!\e[0m\n' && sleep 1
			break
            ;;
		"Disable")
            echo -e '\n\e[31mYou choose disable...\e[0m\n' && sleep 1
			deleteAnoma
			echo -e '\n\e[42mAnoma was disabled!\e[0m\n' && sleep 1
			break
            ;;
        "Quit")
            break
            ;;
        *) echo -e "\e[91minvalid option $REPLY\e[0m";;
    esac
done