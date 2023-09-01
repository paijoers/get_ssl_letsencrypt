# Buat scheduler baru pada MikroTik dengan interval 1d:00:00:00, lalu copy-paste skrip ini ke dalam scheduler Anda.
# Jangan lupa untuk mengedit konfigurasi sesuai kebutuhan Anda.

############### KONFIGURASI ###############

# Nama domain
:local domain "<NAMA_DOMAIN_ANDA>";

# IP server Ubuntu
:local ipsv "<IP_UBUNTU_ANDA>";

# Kredensial pengguna root
:local usr "root";
:local pw "<PASSWORD_ROOT_ANDA>";

# Penyimpanan SSL MikroTik, "set hanya ssl-store jika Anda tidak memiliki disk"
:local storage "disk1/ssl-store";

# Opsi SSL Hotspot, "y" atau "n"
:local hsssl "y";

# Profil server Hotspot
:local hsprofile "hotspot2";

# Opsi IP Services www-ssl, "y" atau "n"
:local wwwssl "y";

# Opsi IP Services api-ssl, "y" atau "n"
:local apissl "n";

############# AKHIR KONFIGURASI #############


:local renewdays "30";
:local pin;
:local pout;
:local dlstatus;

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
        :local remain (([:pick $expires 0 [:find $expires "w"]] * 7) + ([:pick $expires ([:find $expires "w"] + 1) [:find $expires "d"]]));
        :if ($remain < $renewdays) do={
            :do {
                :log warning "Sertifikat SSL $domain akan kedaluwarsa dalam $remain hari.";
                :log warning "Mengunduh sertifikat SSL $domain..";
                /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/fullchain.pem") user="$usr" password="$pw" dst-path=("$storage/$domain.cert.pem");
                /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/privkey.pem") user="$usr" password="$pw" dst-path=("$storage/$domain.key.pem");
                :set dlstatus "success";
                /certificate remove [find where name~"$domain"];
                :log warning "Sertifikat lama berhasil dihapus.";
            } on-error={
                :set dlstatus "error";
                :log warning "Sertifikat SSL gagal diunduh!";
            }

            :if ($dlstatus = "success") do={
                :log warning "Mengimpor sertifikat SSL $domain..";
                :delay 3s;
                /certificate import file-name=("$storage/$domain.cert.pem") passphrase="" name="$domain";
                /certificate import file-name=("$storage/$domain.key.pem") passphrase="" name="$domain";
                :if ($hsssl = "y") do={
                    :log warning "Pengaturan SSL hotspot..";
                    /ip hotspot profile set ssl-certificate=$domain login-by="https,mac-cookie" [find name=$hsprofile];
                } else={
                    /ip hotspot profile set ssl-certificate=none login-by="http-chap,mac-cookie" [find name=$hsprofile];
                }
                :if ($wwwssl = "y") do={
                    :log warning "Pengaturan www-ssl..";
                    /ip service set www-ssl certificate=$domain;
                } else={
                    /ip service set www-ssl certificate=none;
                }
                :if ($apissl = "y") do={
                    :log warning "Pengaturan api-ssl..";
                    /ip service set api-ssl certificate=$domain;
                } else={
                    /ip service set api-ssl certificate=none;
                }
                :log warning "Sertifikat SSL $domain telah diperbarui.";
            }
        } else={
            :log warning "Sertifikat SSL $domain akan kedaluwarsa dalam $remain hari.";
        }
    } else={
        :log warning "Sertifikat $domain tidak ditemukan atau belum terpasang!";
        :do {
            :log warning "Mengunduh sertifikat SSL $domain..";
            /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/fullchain.pem") user="$usr" password="$pw" dst-path=("$storage/$domain.cert.pem");
            /tool fetch url=("sftp://$ipsv/etc/letsencrypt/live/$domain/privkey.pem") user="$usr" password="$pw" dst-path=("$storage/$domain.key.pem");
            :set dlstatus "success";
        } on-error={
            :set dlstatus "error";
            :log warning "Sertifikat SSL gagal diunduh!";
        }
        :if ($dlstatus = "success") do={
            :log warning "Mengimpor sertifikat SSL $domain..";
            /certificate import file-name=("$storage/$domain.cert.pem") passphrase="" name="$domain";
            /certificate import file-name=("$storage/$domain.key.pem") passphrase="" name="$domain";
            :if ($hsssl = "y") do={
                :log warning "Pengaturan SSL hotspot..";
                /ip hotspot profile set ssl-certificate=$domain login-by="https,mac-cookie" [find name=$hsprofile];
            } else={
                /ip hotspot profile set ssl-certificate=none login-by="http-chap,mac-cookie" [find name=$hsprofile];
            }
            :if ($wwwssl = "y") do={
                :log warning "Pengaturan www-ssl..";
                /ip service set www-ssl certificate=$domain;
            } else={
                /ip service set www-ssl certificate=none;
            }
            :if ($apissl = "y") do={
                :log warning "Pengaturan api-ssl..";
                /ip service set api-ssl certificate=$domain;
            } else={
                /ip service set api-ssl certificate=none;
            }
            :log warning "Sertifikat SSL untuk domain $domain berhasil dipasang.";
        }
    }
}
