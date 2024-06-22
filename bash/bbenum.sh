#!/bin/bash

command_exists() {
	command -v "$1" > /dev/null 2>&1
}

checks() {
	local apps=("assetfinder" "amass" "httprobe" "gowitness")
	for cmd in "${apps[@]}"; do
		if ! command_exists "$cmd"; then
			echo "ERROR: $cmd is not installed. Please install it before running this script."
			echo "SYNTAX: sudo apt install $cmd"
			exit 1
		fi
	done
}

start=$(date +%s)

if [ "$1" == "" ]; then
	echo "ERROR: You must input a proper domain."
	echo "SYNTAX: ./bbenum.sh example.com"
	exit 1
fi

url=$1

if [ ! -d "$url" ]; then
	mkdir $url
fi

if [ ! -d "$url/recon" ]; then
	mkdir $url/recon
fi

echo "[+] Harvesting subdomains with assetfinder... [+]"
assetfinder $url >> $url/recon/assets.txt
cat $url/recon/assets.txt | grep $1 >> $url/recon/final.txt
rm -rf $/url/recon/assets.txt

echo "[+] Harvesting subdomains with Amass...       [+]"
amass enum -d $url >> $url/recon/f.txt
sort -u $url/recon/f.txt >> $url/recon/final.txt
rm -rf $url/recon/f.txt

echo "[+] Probing for alive domains...              [+]"
cat $url/recon/final.txt | sort -u | httprobe -s -p https:443 | sed 's/https\?:\/\///' | tr -d ':443' >> $url/recon/alive.txt

echo "[+] Screenshotting websites...                [+}"
cd $url/recon
cat alive.txt | gowitness file -f - > /dev/null 2>&1

end=$(date +%s)
runtime=$((end-start))

echo "[+] ----------------------------------------- [+]"
echo ""
echo "[+] Finished in $runtime seconds.             [+]"
