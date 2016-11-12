#!/bin/sh
set -e
# wait for mysql at least 30 seconds
MYSQL_SLEEP=30
sleep $MYSQL_SLEEP &

## Copy staging.sql file to non-/tmp folder so can debug wreckage.
#sql=/tmp/staging.sql
sql=/staging/load.sql
rm -f $sql
# empty file to start with
touch $sql

cd /staging
# Forget about any incomplete staging
rm -rf staging
mkdir -p staging staged
for file in *.sql.gz ; do
  db=`echo $file | sed 's/\\.gz$//' | sed 's/\\.sql//'`
  staged=staged/$db
  staging=staging/$db
  if ! [ -f $staged ] ; then
    echo "Preparing to stage $db"
    echo "CREATE DATABASE IF NOT EXISTS $db;" >> $sql
    echo "USE $db;" >> $sql
    echo "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;" >> $sql
    gunzip --stdout $file | sed s/InnoDB/MyISAM/ >> $sql
    # workaround for 1.5 mysql dump
    echo 'UPDATE mappingSet SET justification="http://semanticscience.org/resource/SIO_000985" WHERe sourceDataSource="ConceptWiki" AND justification="http://example.com/ConceptWikiProtein";' >> $sql
    touch $staging
  fi
done  
if ! [ -f $sql ] ; then
  echo "mySQL already staged"
  exit 0
fi



# To avoid password warnings..
echo "[client]" > /tmp/my.conf
# echo "host=$MYSQL_PORT_3306_TCP_ADDR" >> /tmp/my.conf
echo "host=127.0.0.1" >> /tmp/my.conf
echo "port=3306" >> /tmp/my.conf
echo "database=ims" >> /tmp/my.conf
echo "user=root" >> /tmp/my.conf
echo "password=uCie0ahgah" >> /tmp/my.conf

echo "$ cat /tmp/my.conf"
cat /tmp/my.conf

# hope that mysql has started
echo "Waiting for mySQL (up to $MYSQL_SLEEP seconds)"
wait
echo "mySQL staging"
ls -alh /tmp/staging.sql

cat $sql | cpipe -vw -b 8192 | mysql --defaults-file=/tmp/my.conf --protocol=TCP
# Mark as staged
mv staging/* staged/
rm -f $sql
echo "mySQL staging finished"

