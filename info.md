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

## Reset installtion
Run the following as Root, and reinstall Payara5, rerun Dataverse installer
- /usr/local/payara5/glassfish/bin/asadmin undeploy dataverse
- /usr/local/payara5/glassfish/bin/asadmin stop-domain
- psql -U dvnapp -c 'DROP DATABASE "dvndb"' template1
- curl http://localhost:8983/solr/collection1/update/json?commit=true -H "Content-type: application/json" -X POST -d "{\"delete\": { \"query\":\"*:*\"}}"
- rm -rf /usr/local/payara5
- /usr/bin/systemctl enable payara.service