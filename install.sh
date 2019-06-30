# --------------------------------------------------------------------------------
# Colibri Build Script
#
# Tested with: Ubuntu18.04LTS
# Date: 21 June 2019
#
# Status: Work in Progress
# --------------------------------------------------------------------------------

#!/bin/bash

source config.ini

#user basic interaction
#waiting for $3 chars injected in $2 var
function wait_until_key_pressed {
  printf "$1"
  while [ true ] ; do
    read -n $3 $2
    if [ $? = 0 ] ; then
      break;
    fi
    # 2 is CRL-C
    if [ $? = 2 ] ; then
      exit;
    fi
  done
}

# who is the user(sudoer) and where is the script ?
user=$(whoami)
script_path=$(pwd)

if [ $install_dependencies == 1 ]
then
  echo "-------------------------------------------------------------"
  echo "updating system......."
  echo "-------------------------------------------------------------"
  sudo apt --fix-broken install
  sudo apt-get update -y
  sudo apt-get upgrade -y
  sudo apt-get dist-upgrade -y
  sudo apt-get clean
  sudo apt --fix-broken install

  echo "-------------------------------------------------------------"
  echo "installing : "
  echo "- curl and gpg"
  echo "- compiler toolchain (needed to install common Ruby gems)"
  echo "- dependencies for ruby : libssl, readline, zlib"
  echo "-------------------------------------------------------------"
  sudo apt-get install -y curl gnupg build-essential
  sudo apt-get install -y libssl-dev libreadline-dev zlib1g-dev

  echo "**************************************************************************"
  echo "**************************************************************************"
  wait_until_key_pressed "basic packages ready - press any key to continue or ctrl-C to abort\n" "" 1

  # at this stage maybe we have to download ruby sources and compile
  # the rbenv/rvm methods seem to not to be suited to production
  # see here for more complete instructions : https://github.com/ruby/ruby#how-to-compile-and-install
  # this will install ruby and bundle in /usr/local/bin
  ruby_bin_path=$(which ruby)
  # this is a one shot install - you keep the ruby version
  if [ ! $ruby_bin_path ]
  then
    echo "-------------------------------------------------------------"
    echo "ruby not present - fetching ruby sources and compiling "
    echo "-------------------------------------------------------------"
    wget $ruby_source_path
    tar -xvf $(ls *tar.xz)
    cd ruby-$ruby_version
    ./configure
    make
    #make update-gems
    #make extract-gems
    sudo make install
  else
    echo "-------------------------------------------------------------"
    echo "ruby already installed in $ruby_bin_path"
    echo "-------------------------------------------------------------"
  fi

  sudo -i gem install bundler
  echo "**************************************************************************"
  echo "**************************************************************************"
  wait_until_key_pressed "ruby and bundle installed - press any key to continue or ctrl-C to abort\n" "" 1
  echo "-------------------------------------------------------------"
  echo "installing Nodejs, as we need a compiler for the assets "
  echo "-------------------------------------------------------------"
  sudo apt-get install -y nodejs
  sudo ln -sf /usr/bin/nodejs /usr/local/bin/node

  echo "-------------------------------------------------------------"
  echo "installing passenger standalone "
  echo "-------------------------------------------------------------"
  sudo apt-get install -y dirmngr gnupg
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
  sudo apt-get install -y apt-transport-https ca-certificates
  # Add APT repository
  sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger bionic main > /etc/apt/sources.list.d/passenger.list'
  sudo apt-get update
  # Install Passenger
  sudo apt-get install -y passenger

  echo "-------------------------------------------------------------"
  echo "installing postgre SQL "
  echo "-------------------------------------------------------------"
  sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
  wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get update -y
  sudo apt-get install -y postgresql-common
  sudo apt-get install -y postgresql-9.5 libpq-dev
  # configure a user
  sudo -u postgres psql -c "CREATE USER $psql_user WITH PASSWORD '$psql_password';"
  sudo -u postgres psql -c "ALTER ROLE $psql_user WITH CREATEDB;"
  sudo useradd $psql_user

  echo "-------------------------------------------------------------"
  echo "installing image utilities "
  echo "-------------------------------------------------------------"
  sudo apt-get install -y imagemagick-6.q16
  sudo apt-get install -y graphicsmagick-imagemagick-compat
  sudo apt-get install -y imagemagick-6.q16hdri
fi


echo "**************************************************************************"
echo "**************************************************************************"
wait_until_key_pressed "SYSTEM READY - PRESS ANY KEY TO INSTALL THE APP or ctrl-C to abort\n" "" 1

if [ ! -d $colibri_path ]
then
  sudo mkdir $colibri_path
  sudo chown $user:$user $colibri_path
fi

git clone http://github.com/alexandrecuer/sharebox $colibri_path/sharebox

cp $script_path/database.yml $colibri_path/sharebox/config/database.yml

cd $colibri_path/sharebox

sed -i "s|.*ruby '[0-9\.]*'.*|ruby '$ruby_version'|" Gemfile
sed -i "s|.*gem 'rails', '~> [0-9\.]*'.*|gem 'rails', '~> $rails_version'|" Gemfile

sed -i "s~your_db_user_name~$psql_user~" .env
sed -i "s~your_db_user_pass~$psql_password~" .env

wait_until_key_pressed "going to launch bundle update - press any key or ctrl-C to abort\n" "" 1
bundle update

if [ $dev == 1 ]
then
  # installing the smbd service for file sharing
  sudo apt-get install -y samba
  # injecting .env in the environment, creating database and running migrations
  set -a
  source .env
  set +a
  bundle exec rake db:create RACK_ENV=development
  bundle exec rake db:migrate RACK_ENV=development
  # in development mode, the server will have to be started with something like that :  bundle exec rails s -b 192.168.1.26 -p 3000
fi

if [ $prod == 1 ]
then
  if [ ! -f Passengerfile.json ]
  then
    echo "-------------------------------------------------------------"
    echo "creating Passengerfile.json "
    echo "-------------------------------------------------------------"
    touch Passengerfile.json
    echo '{' >> Passengerfile.json
    echo '  "environment": "production",' >> Passengerfile.json
    echo '  "port": 80,' >> Passengerfile.json
    echo '  "daemonize": true' >> Passengerfile.json
    echo '}' >> Passengerfile.json
  fi
  
  if [ $(grep "RAILS_SERVE_STATIC_FILES" .env) ]
  then
    echo "RAILS_SERVE_STATIC_FILES already present in .env file"
  else
    echo "RAILS_SERVE_STATIC_FILES=enabled" >> .env
  fi

  if [ $(grep "SECRET_KEY_BASE" .env) ]
  then
    echo "SECRET_KEY_BASE already present in .env file"
  else
    # load env a first time so that bundle can generate secret
    set -a
    source .env
    set +a
    # generate the secret
    secret=$(bundle exec rake secret)
    echo $secret
    # inject the secret
    if [ -n "$secret" ]
    then
      echo "SECRET_KEY_BASE=$secret" >> .env
    fi
  fi

  # env loading second time !! then we can precompile the assets
  set -a
  source .env
  set +a

  bundle exec rake assets:precompile RACK_ENV=production
  bundle exec rake db:create RACK_ENV=production
  bundle exec rake db:schema:load RACK_ENV=production

  # we create the daemon
  if [ ! -f /etc/rc.local ]
  then
    touch rc.local
    echo '#!/bin/bash' >> rc.local
    echo 'cd $colibri_path/sharebox' >> rc.local
    echo 'set -a' >> rc.local
    echo 'source .env' >> rc.local
    echo 'set +a' >> rc.local
    echo 'bundle exec passenger start' >> rc.local
    chmod +x rc.local
    sudo mv rc.local /etc/rc.local
  fi
fi
