#/bin/bash
DB_HOST="<DB Systsem IP address>"
DB_NAME="tc"
DB_ADMIN_USER="mysqladmin"
DB_USER="tc"
echo "Creating DB $DB_NAME"
echo -n "Enter $DB_ADMIN_USER password:"
read -s DB_ADMIN_PWD
mysql -h $DB_HOST -u $DB_ADMIN_USER -p$DB_ADMIN_PWD << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS $DB_USER IDENTIFIED WITH mysql_native_password BY '$DB_ADMIN_PWD';
GRANT ALL ON $DB_NAME.* TO $DB_USER;
EOF

echo "Creating table transcoded_files"
echo -n "Enter $DB_USER password:"
read -s DB_PWD
mysql -h $DB_HOST -D $DB_NAME -u $DB_ADMIN_USER -p$DB_PWD << EOF
use $DB_NAME;
create table if not exists transcoded_files(
   id INT NOT NULL AUTO_INCREMENT,
   name VARCHAR(100) NOT NULL UNIQUE,
   bucket VARCHAR(50) NOT NULL,
   object VARCHAR(100) NOT NULL, 
   create_date DATETIME NOT NULL,
   PRIMARY KEY ( id )
);
EOF
