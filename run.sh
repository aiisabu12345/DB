#!/bin/sh
# รัน DDL + DML + PL ของ SE และ BA ใน container (ใช้ซ้ำได้ เพราะ DDL ลบตารางเดิมก่อน)
for s in SE BA; do
  u=$(echo $s | tr A-Z a-z)
  docker exec -i -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 oracle-db sqlplus -s $u/$u@localhost/FREEPDB1 <<SQL
WHENEVER SQLERROR EXIT FAILURE
@/sql/DDL/$s.sql
@/sql/DML/$s.sql
@/sql/PL/$s.sql
EXIT
SQL
done
