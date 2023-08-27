############### CONFIG ###############

# Domain name
:local domain "<YOUR_DOMAIN>";

# Ubuntu server IP
:local ipsv "<YOUR_IP_UBUNTU>";

# Root user credentials
:local usr "root";
:local pw "<YOUR_ROOT_PASSWORD>";

# MikroTik SSL storage "set ssl-store if you don't have disk"
:local storage "disk1/ssl-store";

# SSL Hotspot option "y" or "n"
:local hsssl "y";

# Hotspot server profile
:local hsprofile "hotspot1";

# IP services www-ssl option "y" or "n"
:local wwwssl "y";

# IP services api-ssl option "y" or "n"
:local apissl "n";

############# END CONFIG #############

## TIME TO WORKING ##
:local pin;
:local pout;

/tool flood-ping $ipsv count=5 size=50 do={
    :if ($sent = 5) do={
        :set pout $sent;
        :set pin $received;
    }
}

:local pinging ([:tonum (100 - (($pin * 100) / $pout))]);

:if ($pinging = "100") do={
    :log warning "Ubuntu server is unreachable!";
} else={
    :local cert [/certificate find where name=$domain];
    :if ($cert != "") do={
        :local expires [/certificate get $domain value-name=expires-after];
        :local weeks [:pick $expires 0 [:find $expires "w"]];
        :local days [:pick $expires ([:find $expires "w"]+1) [:find $expires "d"]];
        :local remain (($weeks*7)+$days);

        :if ($remain <  30) do={
            :log warning "SSL certificate $domain will expire in $remain days";
            :log warning "Removing old certificate...";
            /certificate remove [find where name~"$domain"];
            :delay 3s;
            :log warning "Downloading new SSL...";
            /tool fetch url="sftp://$ipsv/etc/letsencrypt/live/$domain/fullchain.pem" user="$usr" password="$pw" dst-path="$storage/fullchain.pem";
            /tool fetch url="sftp://$ipsv/etc/letsencrypt/live/$domain/privkey.pem" user="$usr" password="$pw" dst-path="$storage/privkey.pem";
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
            :log warning "SSL certificate $domain has been renewed";
        } else={
            :log warning "SSL certificate $domain will expire in $remain days";
        }
    } else={
        :log warning "Certificate $domain not found! You cannot renew the certificate. You must import it first.";
    }
}
