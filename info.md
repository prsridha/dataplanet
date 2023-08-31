## Installation Instructions
Run setup.sh as root in a new RHEL8 instance. Follow the prompts of the dataverse installer. Continue with all default options - required ones will be modified later.

## SMTP configuration
First, we need to update Payara admin credentials. The default credentials are:
- Payara Admin user: admin
- Payara Admin password: \<blank>

Change this via:

/usr/local/payara5/glassfish/bin/asadmin change-admin-password
/usr/local/payara5/glassfish/bin/asadmin enable-secure-admin
/usr/local/payara5/glassfish/bin/asadmin restart-domain

## Debugging
- docs: https://guides.dataverse.org/en/latest/installation/index.html
- payara path: /usr/local/payara5/glassfish/domains/domain1/
- payara asadmin: /usr/local/payara5/glassfish/bin/asadmin

## Restart installation
- /usr/local/payara5/glassfish/bin/asadmin stop-domain
- /usr/local/payara5/glassfish/bin/asadmin start-domain

## Recovery
- Dataset Recovery - https://guides.dataverse.org/en/latest/developers/dataset-migration-api.html?highlight=migration
- Reinstalltion on same Postgres db - follow upgrade instructions of latest release - may or may not work - https://github.com/IQSS/dataverse/releases

## Reset installation
Run the following as Root, and reinstall Payara5, rerun Dataverse installer
- /usr/local/payara5/glassfish/bin/asadmin undeploy dataverse
- /usr/local/payara5/glassfish/bin/asadmin stop-domain
- psql -U dvnapp -c 'DROP DATABASE "dvndb"' template1
- curl http://localhost:8983/solr/collection1/update/json?commit=true -H "Content-type: application/json" -X POST -d "{\"delete\": { \"query\":\"*:*\"}}" OR curl 'http://localhost:8983/solr/collection1/update/json?commit=true' -H -g 'Content-type: application/json' -X POST -d '{"delete": { "query":"*:*"}}'
- rm -rf /usr/local/payara5
- /usr/bin/systemctl enable payara.service

## Publish Dataset Manually
- API_TOKEN=146951f9-d99d-4eac-8db9-d92b6e26060b
- SERVER_URL=https://dataplanet.ucsd.edu
- DATAVERSE_ID=root
- PERSISTENT_IDENTIFIER=perma:20.dataMyData/GAOZVI
- curl -H "X-Dataverse-key:$API_TOKEN" -X POST -k "$SERVER_URL/api/dataverses/$DATAVERSE_ID/datasets/:import?pid=$PERSISTENT_IDENTIFIER&release=yes" --upload-file gao_dataset.json

## KT - todo
- Credentials - dataverseAdmin, asadmin, psql, dataplanet@ucsd.edu
- Apache/Shibboleth certs
- Dashboard walkthrough
- Add to maintainence mailing list - dataplanet servers
- Contact Persons: Me (gmail ID), Matrix elements - pdburin, etc, Daimen
- Dataplanet website files
- Documentation - github, google docs, dataverse docs links
- CURL/asadmin commands
- server.log file locations