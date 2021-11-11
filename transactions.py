Заполнение таблицы
create or replace function insert_my_table(size int)
returns void as $$
   begin
       for i in 0..size - 1 loop
           insert into my_table(Value) values (0);
           end loop;
   end;
$$language plpgsql;

Запрос блокировок
select
  lock.locktype,
  lock.relation::regclass,
  lock.mode,
  lock.transactionid as tid,
  lock.virtualtransaction as vtid,
  lock.pid,
  lock.granted
from pg_catalog.pg_locks lock
  left join pg_catalog.pg_database db
    on db.oid = lock.database
where (db.datname = 'lab_3')
  and not lock.pid = pg_backend_pid()
order by lock.pid;

Тест1
писатель
import psycopg2
import random
import time

con = psycopg2.connect(
  database="lab_3", 
  user="postgres", 
  password="postgres", 
  host="127.0.0.1", 
  port="5432"
)
con.autocommit = True
cur = con.cursor()
while(1):
    i = random.randint(0, 1500000)
    j = random.randint(0, 1500000)
    if i != j:
      request_1 = "update my_table set Value = (Value - 1) where Code = " + str(i) + ";"
      request_2 = "update my_table set Value = (Value + 1) where Code = " + str(j) + ";"
      cur.execute("begin transaction isolation level repeatable read;")
      cur.execute(request_1)
      cur.execute(request_2)
      cur.execute("commit;")
      time.sleep(0.01)

cur.close()  
con.close()

читатель
import psycopg2
import random
import time

con = psycopg2.connect(
  database="lab_3", 
  user="postgres", 
  password="postgres", 
  host="127.0.0.1", 
  port="5432"
)
con.autocommit = True
cur = con.cursor()
z = po = mo = pt = mt = pth = mth = 0
for i in range (100):
  cur.execute("begin transaction isolation level repeatable read;")
  cur.execute("select sum(Value) from my_table;")
  records = cur.fetchall()
  # print(records[0][0], type(records[0][0]))
  if records[0][0] == 0:
    z += 1
  if records[0][0] == 1:
    po += 1
  if records[0][0] == -1:
    mo += 1
  if records[0][0] == 2:
    pt += 1
  if records[0][0] == -2:
    mt += 1

  cur.execute("commit;")
print('0 - ', z)
print('1 - ', po)
print('-1 - ', mo)
print('2 - ', pt)
print('-2 - ', mt)

cur.close()  
con.close()


Тест2 
писатель
con.autocommit = True
cur = con.cursor()
cur.execute("begin transaction isolation level serializable;")
cur.execute("insert into my_table(Code, Value) values (default, 111);")
time.sleep(0.01)
cur.execute("commit;")
cur.close()  
con.close()

читатель
con.autocommit = True
cur = con.cursor()
cur.execute("begin transaction isolation level serializable;")
cur.execute("select sum(Value) from my_table;")
print(cur.fetchall())
print('Time to sleep')
time.sleep(5)
cur.execute("select sum(Value) from my_table;")
print(cur.fetchall())
cur.execute("commit;")
cur.close()  
con.close()



Тест 3
писатель
con.autocommit = True
cur = con.cursor()
cur.execute("begin transaction isolation level read uncommitted;")
cur.execute("insert into my_table(Code, Value) values (default, 111);")
print('Time to sleep')
time.sleep(5)
cur.execute("rollback;")
cur.close()  
con.close()

читатель
con.autocommit = True
cur = con.cursor()
cur.execute("begin transaction isolation level read uncommitted;")
cur.execute("select sum(Value) from my_table;")
print(cur.fetchall())
time.sleep(5)
cur.execute("select sum(Value) from my_table;")
print(cur.fetchall())
cur.execute("commit;")

Тест 4
писатель1
con.autocommit = True
cur = con.cursor()
cur.execute("begin transaction isolation level serializable;")
cur.execute("insert into my_table (Code, Value) values (1200000, 111);")
time.sleep(0.1)
cur.execute("commit;")
cur.close()  
con.close()

писатель2
con.autocommit = True
cur = con.cursor()
cur.execute("begin transaction isolation level serializable;")
cur.execute("select sum(Value) from my_table;")
sum = cur.fetchall()
print('Time to sleep')
time.sleep(3)
if sum == 0:
    cur.execute("insert into my_table (Code, Value) values (1200000, 111);")
cur.execute("commit;")
cur.close()  
con.close()

Код для отслеживания блокировок
cur.execute('''select count(*) from (select
  lock.locktype,
  lock.relation::regclass,
  lock.mode,
  lock.transactionid as tid,
  lock.virtualtransaction as vtid,
  lock.pid,
  lock.granted
  from pg_catalog.pg_locks lock
  left join pg_catalog.pg_database db
    on db.oid = lock.database
    where (db.datname = 'lab_3')
  and not lock.pid = pg_backend_pid()
  order by lock.pid) as zap;''')
  blocks = cur.fetchall()
  if blocks[0][0] != 0:
      cur.execute('''select
      lock.locktype,
      lock.relation::regclass,
      lock.mode,
      lock.transactionid as tid,
      lock.virtualtransaction as vtid,
      lock.pid,
      lock.granted
      from pg_catalog.pg_locks lock
      left join pg_catalog.pg_database db
      on db.oid = lock.database
      where (db.datname = 'lab_3')
      and not lock.pid = pg_backend_pid()
      order by lock.pid;''')
      blockss = cur.fetchall()
      for row in blockss:
          print(row)
