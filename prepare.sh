#!/bin/sh

HAS_GIT=`command -v git`
HAS_GO=`command -v go`
HAS_NPM=`command -v npm`
HAS_PSQL=`command -v psql`
HAS_REDIS=`command -v redis-cli`

# Install packages based on available package manager
if  [ -z "$HAS_GIT" -o -z "$HAS_GO" -o -z "$HAS_NPM" -o -z "$HAS_PSQL" -o -z "$HAS_REDIS" ]; then
    echo "Installing prerequisites"
    if command -v apt-get > /dev/null; then # Debian and Ubuntu based
        sudo add-apt-repository ppa:redislabs/redis
        sudo apt-get update
        sudo apt-get install git golang postgresql postgresql-contrib redis

        # Ckeck if node is installed and install it using nvm if it is not
        HAS_NVM=`command -v nvm`
        if [ -z "$HAS_NVM" -a -z "$HAS_NPM" ]; then
            wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
        fi

        if [ -z "$HAS_NPM" ]; then
            nvm install node
            nvm use node
        fi

        if [ -z "$HAS_PSQL" ]; then
            sudo cat "/etc/postgresql/13/main/pg_hba.conf" | sed "s/local\(\ *\)all\(\ *\)all\(\ *\)peer/local\1all\2all\3md5/" | 
                sudo tee "/etc/postgresql/13/main/pg_hba.conf" > /dev/null
            sudo runuser -l postgres -c "psql -c \"CREATE ROLE hakaton SUPERUSER LOGIN PASSWORD 'sifra';\""
            sudo runuser -l postgres -c "psql -c \"CREATE DATABASE hakaton owner=hakaton;\""
        fi

        if [ -z "$HAS_REDIS" ]; then
            sudo cat "/etc/redis/redis.conf" | sed "s/# requirepass foobared/requirepass sifra/" | 
                sudo tee "/etc/redis/redis.conf" > /dev/null
            sudo systemctl enable --now redis-server
        fi

    elif command -v pacman > /dev/null; then # Arch based
        sudo pacman -Sy git npm go postgresql redis

        if [ -z "$HAS_PSQL" ]; then
            sudo runuser -l postgres -c "initdb --locale=en_US.UTF-8 -E UTF8 -D /var/lib/postgres/data"
            sudo cat "/var/lib/postgres/data/pg_hba.conf" | sed "s/local\(\ *\)all\(\ *\)all\(\ *\)peer/local\1all\2postgres\3peer\nlocal\1all\2all\3md5\n/" |
                sudo tee "/var/lib/postgres/data/pg_hba.conf" > /dev/null
            sudo runuser -l postgres -c "psql -c \"CREATE ROLE hakaton SUPERUSER LOGIN PASSWORD 'sifra';\""
            sudo runuser -l postgres -c "psql -c \"CREATE DATABASE hakaton owner=hakaton;\""
            sudo systemctl enable postgresql
            sudo systemctl start postgresql
        fi

        if [ -z "$HAS_REDIS" ]; then
            sudo cat "/etc/redis/redis.conf" | sed "s/# requirepass foobared/requirepass sifra/" | 
                sudo tee "/etc/redis/redis.conf" > /dev/null
            sudo systemctl enable --now redis
        fi

    elif command -v dnf > /dev/null; then # Redhat, Fedora, SUSE
        sudo dnf install git npm postgresql-server postgresql-contrib redis
        
        if [ -z "$HAS_PSQL" ]; then
            sudo cat "/var/lib/pgsql/data/pg_hba.conf" | sed "s/local\(\ *\)all\(\ *\)all\(\ *\)peer/local\1all\2postgres\3peer\nlocal\1all\2all\3md5\n/" |
                sudo tee "/var/lib/pgsql/data/pg_hba.conf" > /dev/null
            sudo runuser -l postgres -c "psql -c \"CREATE ROLE hakaton SUPERUSER LOGIN PASSWORD 'sifra';\""
            sudo runuser -l postgres -c "psql -c \"CREATE DATABASE hakaton owner=hakaton;\""
            sudo systemctl enable postgresql
            sudo postgresql-setup --initdb --unit postgresql
            sudo systemctl start postgresql
        fi

        if [ -z "$HAS_REDIS" ]; then
            sudo cat "/etc/redis/redis.conf" | sed "s/# requirepass foobared/requirepass sifra/" | 
                sudo tee "/etc/redis/redis.conf" > /dev/null
            sudo systemctl enable --now redis
        fi
    else 
        echo "Couldn't find known package manager, please install needed packages manually"
        exit 1
    fi
fi

# make a project directory
mkdir -p hakaton
cd hakaton

# clone front-end and install dependencies
git clone "https://gitlab.com/predvodnik/hakaton-front.git"
cd hakaton-front
npm i


# clone back-end
git clone "https://gitlab.com/predvodnik/hakaton-back.git"
cd hakaton-back
ssh-keygen -t rsa -f keys/key.pem -m pem

echo
echo "-------------------------------"
echo
echo "Everything is set up, please restart terminal window for changes to take effect"