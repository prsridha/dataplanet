# tested on RHEL 8

RHEL_VERSION=8
DATAVERSE_VERSION=5.14

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# update packages and install dependencies
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
yum update -y
yum install -y git
yum install -y wget
yum install -y nano
yum install -y unzip
yum install -y lsof
yum install -y python39
yum install -y libcurl-devel
yum install -y openssl-devel
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$RHEL_VERSION.noarch.rpm

# download dataverse repo
git clone -b master https://github.com/IQSS/dataverse.git

# install Java 11 (needs to be the default Java version)
yum install -y java-11-openjdk

# create a new user named dataverse
useradd dataverse

# pull Dataverse files
wget https://github.com/IQSS/dataverse/releases/download/v$DATAVERSE_VERSION/dvinstall.zip
unzip dvinstall.zip -d /tmp

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Payara 5.2022.3
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install Payara
wget https://nexus.payara.fish/repository/payara-community/fish/payara/distributions/payara/5.2022.3/payara-5.2022.3.zip
unzip payara-5.2022.3.zip
mv payara5 /usr/local

# give new user access to Payara directories
chown -R root:root /usr/local/payara5
chown dataverse /usr/local/payara5/glassfish/lib
chown -R dataverse:dataverse /usr/local/payara5/glassfish/domains/domain1

# add Payara as a systemd service
wget https://guides.dataverse.org/en/latest/_downloads/c08a166c96044c52a1a470cc2ff60444/payara.service
cp payara.service /etc/systemd/system/payara.service
/usr/bin/systemctl enable payara.service


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# PostgreSQL
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install PostgreSQL
yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$RHEL_VERSION-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum makecache -y
dnf module disable -y postgresql
yum install -y postgresql13-server
/usr/pgsql-13/bin/postgresql-13-setup initdb
/usr/bin/systemctl start postgresql-13
/usr/bin/systemctl enable postgresql-13

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

# create new user
useradd solr
mkdir /usr/local/solr
chown solr:solr /usr/local/solr

# switch to new user and install Solr
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
wget https://guides.dataverse.org/en/latest/_downloads/0736976a136678bbc024ce423b223d3a/solr.service
cp solr.service /etc/systemd/system
systemctl daemon-reload
systemctl start solr.service
systemctl enable solr.service

# secure solr
usermod -s /sbin/nologin solr

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Other requirements
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# install jq
yum install -y jq

# install R
dnf install dnf-plugins-core
dnf config-manager --set-enabled "codeready-builder-for-rhel-$RHEL_VERSION-*-rpms"
yum install -y R-core R-core-devel

# install R packages
Rscript -e 'install.packages("R2HTML", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
Rscript -e 'install.packages("rjson", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
Rscript -e 'install.packages("DescTools", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
Rscript -e 'install.packages("Rserve", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'
Rscript -e 'install.packages("haven", repos="https://cloud.r-project.org/", lib="/usr/lib64/R/library")'

# configure Rserve
wget https://guides.dataverse.org/en/latest/_downloads/c4ec1d93992cccdb3e9633221d7b153e/rserve.service
cp rserve.service /usr/lib/systemd/system
bash dataverse/scripts/r/rserve/rserve-setup.sh
systemctl daemon-reload
systemctl enable rserve
systemctl start rserve

# install counter processor
cd /usr/local
wget https://github.com/CDLUC3/counter-processor/archive/v0.1.04.tar.gz
tar xvfz v0.1.04.tar.gz
useradd counter
chown -R counter:counter /usr/local/counter-processor-0.1.04
python3.9 -m ensurepip
cd /usr/local/counter-processor-0.1.04
pip3 install -r requirements.txt
pip3 install psycopg2-binary
cd /root


#TODO: remove this after setting up mail server
yum install -y nc
nc -l 25 &

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install Dataverse
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# extract dvinstall
sudo -u dataverse bash << EOF
cd /home/dataverse
wget https://github.com/IQSS/dataverse/releases/download/v$DATAVERSE_VERSION/dvinstall.zip
unzip -d /home/dataverse/ dvinstall.zip
cd /home/dataverse/dvinstall
python3 install.py
EOF

# Persistent Identifiers with Permalinks:
curl -X PUT -d perma http://localhost:8080/api/admin/settings/:Protocol
curl -X PUT -d 20.data http://localhost:8080/api/admin/settings/:Authority
curl -X PUT -d "MyData/" http://localhost:8080/api/admin/settings/:Shoulder
/usr/local/payara5/glassfish/bin/asadmin stop-domain
/usr/local/payara5/glassfish/bin/asadmin start-domain

# Database path
sudo mkdir /dataverse_files
/usr/local/payara5/glassfish/bin/asadmin $ASADMIN_OPTS create-jvm-options "\-Ddataverse.files.file.directory=/dataverse_files"

# SMTP
# /usr/local/payara5/glassfish/bin/asadmin delete-javamail-resource mail/notifyMailSession
# /usr/local/payara5/glassfish/bin/asadmin create-javamail-resource --mailhost smtp.gmail.com --mailuser pradypantry5 --fromaddress pradypantry5@gmail.com --property mail.smtp.auth=true:mail.smtp.password=oops:mail.smtp.port=465:mail.smtp.socketFactory.port=465:mail.smtp.socketFactory.fallback=false:mail.smtp.socketFactory.class=javax.net.ssl.SSLSocketFactory mail/notifyMailSession