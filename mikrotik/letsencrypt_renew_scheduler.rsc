# Buat scheduler baru pada MikroTik interval 1d:00:00:00  dan kemudian copy-paste skrip ini ke dalam scheduler Anda.
# Edit konfigurasi Anda.

############### KONFIGURASI ###############

# Nama domain
:local domain "<NAMA_DOMAIN_ANDA>";

# IP server Ubuntu
:local ipsv "<IP_UBUNTU_ANDA>";

# Kredensial pengguna root
:local usr "root";
:local pw "<PASSWORD_ROOT_ANDA>";

# Penyimpanan SSL MikroTik "set hanya ssl-store jika Anda tidak memiliki disk"
:local storage "disk1/ssl-store";

# Opsi SSL Hotspot "y" atau "n"
:local hsssl "y";

# Profil server Hotspot
:local hsprofile "hotspot2";

# Opsi IP Services www-ssl "y" atau "n"
:local wwwssl "y";

# Opsi IP Services api-ssl "y" atau "n"
:local apissl "n";

############# AKHIR KONFIGURASI #############


:local pin;
:local pout;

/tool flood-ping $ipsv count=5 size=50 do={
    :if ($sent = 5) do={
        :set pout $sent;
        :set pin $received;
    }
}

:local pinging ([:tonum (100 - (($pin * 100) / $pout))]);

:if ($pinging = 100) do={
    :log warning "Server Ubuntu tidak dapat dijangkau!";
} else={
    :local cert [/certificate find where name=$domain];
    :if ($cert != "") do={
        :local expires [/certificate get $domain value-name=expires-after];
        :local weeks [:pick $expires 0 [:find $expires "w"]];
        :local days [:pick $expires ([:find $expires "w"] + 1) [:find $expires "d"]];
        :local remain (($weeks * 7) + $days);

        :if ($remain < 30) do={
            :log warning "Sertifikat SSL untuk $domain akan kedaluwarsa dalam $remain hari.";
            :log warning "Menghapus sertifikat lama...";
            /certificate remove [find where name~"$domain"];
            :delay 3s;
            :log warning "Mengunduh sertifikat SSL baru...";
            /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/fullchain.pem") user="$usr" password="$pw" dst-path="$storage/fullchain.pem";
            /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/privkey.pem") user="$usr" password="$pw" dst-path="$storage/privkey.pem";
            :log warning "Mengimpor sertifikat SSL baru...";
            /certificate import file-name="$storage/fullchain.pem" passphrase="" name="$domain";
            /certificate import file-name="$storage/privkey.pem" passphrase="" name="$domain";
            :if ($hsssl = "y") do={
                /ip hotspot profile set ssl-certificate=$domain login-by="https,mac-cookie" [find name=$hsprofile];
            } else={
                /ip hotspot profile set ssl-certificate=none login-by="http-chap,mac-cookie" [find name=$hsprofile];
            }
            :if ($wwwssl = "y") do={
                /ip service set www-ssl certificate=$domain;
            } else={
                /ip service set www-ssl certificate=none;
            }
            :if ($apissl = "y") do={
                /ip service set api-ssl certificate=$domain;
            } else={
                /ip service set api-ssl certificate=none;
            }
            :delay 2s;
            :log warning "Sertifikat SSL untuk $domain telah diperbarui.";
        } else={
            :log warning "Sertifikat SSL untuk $domain akan kedaluwarsa dalam $remain hari.";
        }
    } else={
        :log warning "Mengunduh sertifikat SSL baru...";
        /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/fullchain.pem") user="$usr" password="$pw" dst-path="$storage/fullchain.pem";
        /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/privkey.pem") user="$usr" password="$pw" dst-path="$storage/privkey.pem";
        :log warning "Mengimpor sertifikat SSL baru...";
        /certificate import file-name="$storage/fullchain.pem" passphrase="" name="$domain";
        /certificate import file-name="$storage/privkey.pem" passphrase="" name="$domain";
        :log warning "Sertifikat baru untuk domain $domain telah diimpor.";
    }
}
