RHEL_VERSION=8
DATAVERSE_VERSION=5.14

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# update packages and install dependencies
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sudo yum update -y
sudo yum install -y git
sudo yum install -y wget
sudo yum install -y nano
sudo yum install -y unzip
sudo yum install -y lsof
sudo yum install -y python39
sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$RHEL_VERSION.noarch.rpm

# download dataverse repo
git clone -b master https://github.com/IQSS/dataverse.git

# install Java 11 (needs to be the default Java version)
sudo yum install -y java-11-openjdk

# create a new user named dataverse
sudo useradd dataverse

# pull Dataverse files
wget https://github.com/IQSS/dataverse/releases/download/v$DATAVERSE_VERSION/dvinstall.zip
unzip dvinstall.zip -d /tmp

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Payara 5.2022.3
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install Payara
wget https://nexus.payara.fish/repository/payara-community/fish/payara/distributions/payara/5.2022.3/payara-5.2022.3.zip
unzip payara-5.2022.3.zip
sudo mv payara5 /usr/local

# give new user access to Payara directories
sudo chown -R root:root /usr/local/payara5
sudo chown dataverse /usr/local/payara5/glassfish/lib
sudo chown -R dataverse:dataverse /usr/local/payara5/glassfish/domains/domain1

# add Payara as a systemd service
sudo cp payara.service /etc/systemd/system/payara.service
sudo /usr/bin/systemctl enable payara.service


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# PostgreSQL
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install PostgreSQL
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$RHEL_VERSION-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum makecache -y
sudo dnf module disable postgresql
sudo yum install -y postgresql13-server
sudo /usr/pgsql-13/bin/postgresql-13-setup initdb
sudo /usr/bin/systemctl start postgresql-13
sudo /usr/bin/systemctl enable postgresql-13

# replace sha-256 with md5 in postgresql conf file
PG_HBA_FILE="/var/lib/pgsql/13/data/pg_hba.conf"
SEARCH_LINE="host    all             all             127.0.0.1\/32            scram-sha-256"
REPLACE_LINE="host    all             all             127.0.0.1\/32            md5"
sudo sed -i "s/$SEARCH_LINE/$REPLACE_LINE/" "$PG_HBA_FILE"

# restart postgres
sudo systemctl restart postgresql-13

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Solr
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# create new user
sudo useradd solr
sudo mkdir /usr/local/solr
sudo chown solr:solr /usr/local/solr

# switch to new user and install Solr
original_user=$(whoami)
sudo -u solr bash << EOF
# Commands to run as the target user
cd /usr/local/solr
wget https://archive.apache.org/dist/lucene/solr/8.11.1/solr-8.11.1.tgz
tar xvzf solr-8.11.1.tgz
cd solr-8.11.1
cp -r server/solr/configsets/_default server/solr/collection1
cp /tmp/dvinstall/schema*.xml /usr/local/solr/solr-8.11.1/server/solr/collection1/conf
cp /tmp/dvinstall/solrconfig.xml /usr/local/solr/solr-8.11.1/server/solr/collection1/conf

JETTY_FILE="/usr/local/solr/solr-8.11.1/server/etc/jetty.xml"
SEARCH_LINE="<Set name=\"requestHeaderSize\"><Property name=\"solr.jetty.request.header.size\" default=\"8192\" \/><\/Set>"
REPLACE_LINE="<Set name=\"requestHeaderSize\"><Property name=\"solr.jetty.request.header.size\" default=\"102400\" \/><\/Set>"
sed -i "s/$SEARCH_LINE/$REPLACE_LINE/" "$JETTY_FILE"
echo "name=collection1" > /usr/local/solr/solr-8.11.1/server/solr/collection1/core.properties
EOF

# add solr to systemd
sudo cp solr.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl start solr.service
sudo systemctl enable solr.service

# secure solr
sudo usermod -s /sbin/nologin solr

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Other requirements
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install jq
sudo yum install -y jq

# install R
R_VERSION=4.2.3
sudo dnf install dnf-plugins-core
sudo dnf config-manager --set-enabled "codeready-builder-for-rhel-$RHEL_VERSION-*-rpms"
# curl -O https://cdn.rstudio.com/r/centos-8/pkgs/R-${R_VERSION}-1-1.x86_64.rpm
# sudo yum install -y R-${R_VERSION}-1-1.x86_64.rpm
sudo yum install -y R-core R-core-devel

# install R packages
sudo Rscript -e 'install.packages("R2HTML", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("rjson", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("DescTools", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("Rserve", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("haven", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'

# configure Rserve
cd dataverse/scripts/r/rserve
sudo bash rserve-setup.sh
sudo systemctl daemon-reload
sudo systemctl enable rserve
sudo systemctl start rserve

# install counter processor
cd /usr/local
sudo wget https://github.com/CDLUC3/counter-processor/archive/v0.1.04.tar.gz
sudo tar xvfz v0.1.04.tar.gz
sudo useradd counter
sudo chown -R counter:counter /usr/local/counter-processor-0.1.04

python3.9 -m ensurepip
cd /usr/local/counter-processor-0.1.04
pip3 install -r requirements.txt

pip3 install psycopg2-binary