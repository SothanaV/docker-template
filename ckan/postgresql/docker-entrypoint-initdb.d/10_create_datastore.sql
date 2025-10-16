\set datastore_ro_password '\'' `echo $DATASTORE_READONLY_PASSWORD` '\''
\set ON_ERROR_STOP on

CREATE ROLE datastore_ro NOSUPERUSER NOCREATEDB NOCREATEROLE LOGIN PASSWORD :datastore_ro_password;
CREATE DATABASE datastore OWNER ckan ENCODING 'utf-8';
GRANT ALL PRIVILEGES ON DATABASE datastore TO ckan;
