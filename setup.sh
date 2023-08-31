# tested on RHEL 8

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
sudo yum install -y libcurl-devel
sudo yum install -y openssl-devel
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$RHEL_VERSION.noarch.rpm
sudo update-alternatives --config python3

# download dataverse repo
cd dataverse
git clone -b master https://github.com/IQSS/dataverse.git

# install Java 11 (needs to be the default Java version)
sudo yum install -y java-11-openjdk

# create a new user named dataverse
# useradd dataverse

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
sudo chown -R prsridha /usr/local/payara5/glassfish/lib
sudo chown -R prsridha /usr/local/payara5/glassfish/domains/domain1

# add Payara as a systemd service
wget https://guides.dataverse.org/en/latest/_downloads/c08a166c96044c52a1a470cc2ff60444/payara.service
sudo cp payara.service /etc/systemd/system/payara.service
sudo /usr/bin/systemctl enable payara.service


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# PostgreSQL
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install PostgreSQL
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum makecache -y
sudo dnf module disable -y postgresql
sudo yum install -y postgresql13-server
sudo /usr/pgsql-13/bin/postgresql-13-setup initdb
sudo /usr/bin/systemctl start postgresql-13
sudo /usr/bin/systemctl enable postgresql-13

# TODO: fix security risk
# replace sha-256 with trust in postgresql conf file
pg_hba_orig="/var/lib/pgsql/13/data/pg_hba.conf"
pg_hba_copy="/var/lib/pgsql/13/data/pg_hba.conf.bak"
sudo cp $pg_hba_orig $pg_hba_copy
sed -E -i "s/scram-sha-256/trust/g" "$pg_hba_orig"
sed -E -i "s/peer/trust/g" "$pg_hba_orig"

# allow listen_addresses
psql_conf="/var/lib/pgsql/13/data/postgresql.conf"
text1="#listen_addresses = 'localhost'"
text2="listen_addresses = '*'"
sed -E -i "s/$text1/$text2/" "$psql_conf"

# restart postgres
systemctl restart postgresql-13

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Solr
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# create solr dirs
mkdir /usr/local/solr
chown -R prsridha /usr/local/solr

# switch to new user and install Solr
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

# add solr to systemd
# change user in service file if your user is not solr
wget https://guides.dataverse.org/en/latest/_downloads/0736976a136678bbc024ce423b223d3a/solr.service
sudo cp solr.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl start solr.service
sudo systemctl enable solr.service

# secure solr
usermod -s /sbin/nologin solr

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Other requirements
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install jq
sudo yum install -y jq

# install R
# try "/usr/bin/crb enable" if the below commands don't work
sudo dnf install dnf-plugins-core
sudo dnf config-manager --set-enabled "codeready-builder-for-rhel-8-*-rpms"
sudo yum install -y R-core R-core-devel

# install R packages
sudo Rscript -e 'install.packages("R2HTML", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("rjson", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("DescTools", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("Rserve", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
sudo Rscript -e 'install.packages("haven", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'

# configure Rserve
wget https://guides.dataverse.org/en/latest/_downloads/c4ec1d93992cccdb3e9633221d7b153e/rserve.service
sudo cp rserve.service /usr/lib/systemd/system
sudo dataverse/scripts/r/rserve/rserve-setup.sh
sudo systemctl daemon-reload
sudo systemctl enable rserve
sudo systemctl start rserve

# install counter processor
wget https://github.com/CDLUC3/counter-processor/archive/v0.1.04.tar.gz
tar xvfz v0.1.04.tar.gz
sudo mv counter-processor-0.1.04 /usr/local
sudo chown -R prsridha /usr/local/counter-processor-0.1.04
python3.9 -m ensurepip
cd /usr/local/counter-processor-0.1.04
sudo pip3 install -r requirements.txt
sudo pip3 install psycopg2-binary

#TODO: remove this after setting up mail server
yum install -y nc
nc -l 25 &

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install Dataverse
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# extract dvinstall
cd ~/dataverse
wget https://github.com/IQSS/dataverse/releases/download/v5.14/dvinstall.zip
unzip dvinstall.zip
cd dvinstall
python3 install.py

# change Payara admin password
/usr/local/payara5/glassfish/bin/asadmin change-admin-password
/usr/local/payara5/glassfish/bin/asadmin enable-secure-admin
/usr/local/payara5/glassfish/bin/asadmin restart-domain

# Persistent Identifiers with Permalinks:
curl -X PUT -d perma http://localhost:8080/api/admin/settings/:Protocol
curl -X PUT -d 20.data http://localhost:8080/api/admin/settings/:Authority
curl -X PUT -d "MyData/" http://localhost:8080/api/admin/settings/:Shoulder
/usr/local/payara5/glassfish/bin/asadmin restart-domain

# Database path
sudo mkdir /home/prsridha/tmp_dataverse_files
/usr/local/payara5/glassfish/bin/asadmin create-jvm-options "\-Ddataverse.files.file.directory=/home/prsridha/tmp_dataverse_files"
chown -R prsridha /home/prsridha/tmp_dataverse_files

# SMTP
/usr/local/payara5/glassfish/bin/asadmin delete-javamail-resource mail/notifyMailSession
/usr/local/payara5/glassfish/bin/asadmin create-javamail-resource --mailhost smtp.ucsd.edu --mailuser grader-dsc102-01@ucsd.edu --fromaddress grader-dsc102-01@ucsd.edu mail/notifyMailSession
/usr/local/payara5/glassfish/bin/asadmin restart-domain

# Apache
sudo yum install -y httpd mod_ssl
sudo cp shibboleth.form /etc/yum.repos.d/shibboleth.repo
sudo yum install -y shibboleth

# Make sure Payara is using 8080 and 8181
/usr/local/payara5/glassfish/bin/asadmin set server-config.network-config.network-listeners.network-listener.http-listener-1.port=8080
/usr/local/payara5/glassfish/bin/asadmin set server-config.network-config.network-listeners.network-listener.http-listener-2.port=8181

# Verify network listener this should have a single result - jk-connector
/usr/local/payara5/glassfish/bin/asadmin list-network-listeners | grep jk-connector

# hide additional warnings
/usr/local/payara5/glassfish/bin/asadmin set-log-levels org.glassfish.grizzly.http.server.util.RequestUtils=SEVERE

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Apache and Shibboleth Configurations
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# copy the virtual host config file
sudo cp VirtualHost /etc/httpd/conf.d/dataplanet.uscd.edu.conf

# Edit Apache ssl.conf - refer to docs
# https://guides.dataverse.org/en/latest/installation/shibboleth.html#id16

# Add shibboleth2.xml file
sudo cp shibboleth2.xml /etc/shibboleth/shibboleth2.xml

# Add the dataverse-idp-metadata.xml file
sudo cp dataverse-idp-metadata.xml /etc/shibboleth/dataverse-idp-metadata.xml

# Add attribute file
wget https://guides.dataverse.org/en/latest/_downloads/2fa33ab92f96836906cbf6d9d3badeb9/attribute-map.xml
sudo cp attribute-map.xml /etc/shibboleth/attribute-map.xml

# SSL config
# add cert file paths in ssl.conf