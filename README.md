# colibri

installation scripts for sharebox application

designed for ubuntu 18.04 LTS

if git not present
```
sudo apt-get install git
```

if /var/www was not created as a specific mount point, create it manually
```
sudo mkdir /war/www
sudo chown pi:pi /var/www
```

then clone the repo
```
git clone https://github.com/alexandrecuer/colibriScripts
cd colibriScripts
./install.sh
```


# samba

if you wish to use samba to share files with your microsoft windows host machine, please do the following, after the installation process has come to an end :

```
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.old
sudo cp /home/pi/colibriScripts/smb.conf /etc/samba/smb.conf
sudo systemctl restart smbd
```

