#!/bin/bash

# Get Let's Encrypt SSL
# TikTok    : @nys.pjr 
# Tested OS : Armbian 20.10 (Ubuntu Bionic) & Armbian 21.08.1 (Ubuntu Focal)

echo -e "\e[1;33m\n***** Mendapatkan Let's Encrypt SSL *****\n\e[0m"

# Menginstal Letsencript jika belum terpasang
if ! command -v letsencrypt &> /dev/null; then
    echo "- Menginstal Lets Encrypt.."
    sudo apt-get install letsencrypt -y
fi

# Mengunduh skrip acme-dns-auth.py jika belum ada
if [[ ! -f /etc/letsencrypt/acme-dns-auth.py ]]; then
    echo -e "\n- Mengunduh file acme-dns-auth.py.."
    sudo curl -o /etc/letsencrypt/acme-dns-auth.py https://raw.githubusercontent.com/joohoi/acme-dns-certbot-joohoi/master/acme-dns-auth.py
    sudo chmod 0700 /etc/letsencrypt/acme-dns-auth.py
fi

# Meminta pengguna untuk memasukkan domain
read -p $'\e[1;33mMasukkan nama domain Anda :\e[0m ' domain

# Meminta pengguna untuk memilih opsi SSL wildcard
read -p $'\e[1;33mApakah Anda ingin menggunakan SSL wildcard? (y/n) :\e[0m ' wildcard_option

# Mengatur opsi Certbot berdasarkan pilihan pengguna
certbot_options="--manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --debug-challenges -d $domain"
if [[ $wildcard_option == "y" ]]; then
    certbot_options+=" -d *.$domain"
fi

# Menggunakan Certbot untuk mendapatkan sertifikat SSL
sudo certbot certonly $certbot_options
exit 0
