# colibri

installation scripts for sharebox application

designed for ubuntu 18.04 LTS

if git not present
```
sudo apt-get install git
```

if /var/www was not created as a specific mount point, create it manually
if logged as a sudoer :
```
sudo mkdir /var/www
```
if you want to have a specific user (eg pi which can act as a suoder) to manage /var/www :
```
sudo chown pi:pi /var/www
```

then clone the repo
```
git clone https://github.com/alexandrecuer/colibriScripts
cd colibriScripts
./install.sh
```
To make the production server work with local files, edit /config/environments/production.rb

```
config.local_storage = 1
```
if `/var/www/colibri/sharebox/forge/attachments` is not automatically created, create it !



# samba

if you wish to use samba to share files with your microsoft windows host machine, please do the following, after the installation process has come to an end :

```
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.old
sudo cp /home/pi/colibriScripts/smb.conf /etc/samba/smb.conf
sudo systemctl restart smbd
```
# create user pi as a sudoer

```
sudo useradd -m -G root pi
```
check :

```
groups pi
```
# remove an old install of ruby on ubuntu

```
sudo apt-get remove ruby

```
