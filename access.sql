create user admin_user;
create user client_user;

grant select(Master, Box, Start_W, End_W, Work), insert(Master, Client, Start_W, Work) on table Schedule to client_user;

alter table Schedule enable row level security;
create policy check_select_Schedule on Schedule for select using (client = current_user);

-- SP 
-- Чтобы клиент мог просматривать существующее расписание мастеров (для всех клиентов)
create view Schedule_for_client_select as select Master, Box, Start_W, End_W from Schedule;
	grant select on table Schedule_for_client_select to client_user;

-- Чтобы клиент мог добавить новую запись на обслуживание

create view Schedule_for_client_insert as select Master, Client, Start_W, Work from Schedule;
grant insert on table Schedule_for_client_insert to client_user;


--Чтобы клиент мог видеть стоимость работ(только свои данные) и данные своих автомобилей. Несмотря на то, что для представлений в БД нельзя реализовать политики, сделать данное разграничение возможно с помощью правильно формулировки запроса при создании представления
create view Schedule_for_client_select_own as select Client, Cost, Work from Schedule where Client = current_user;
grant select on table Schedule_for_client_select_own to client_user;

create view Schedule_for_admin as select box, avg(End_W - Start_W)  from Schedule as s1 where Box = (select distinct Box from Schedule where s1.box = box) group by s1.box;
grant select on table Schedule_for_admin to admin_user;


-- Триггер для проверки наличия мойки перед ремонтом
create or replace function Wash()
 returns trigger as $$
    begin
        if (NEW.Work != 'Мойка автомобиля'and (select count(Client) from Schedule where Client = NEW.Client) = 0) then
            insert into Schedule values (NEW.Master, NEW.Client, check_box(), NEW.Car, 500, NEW.Start_W - interval '30 minutes', NEW.Start_W, 'Мойка автомобиля');
            return NEW;
        end if;
        return NEW;
    end;

$$ language plpgsql;


drop trigger if exists check_wash on Schedule;
create trigger check_wash before insert on Schedule for each row execute procedure Wash();


-- Функция проверки занятости бокса

create function check_box()
returns int as $$
    begin
        if ((select count(Box) from Schedule where Box = 1) = 0)
            then  return  1;
        end if;
         return 2;
    end;
    $$ language plpgsql;

-- Триггер для проверки того, что приемы в боксах не должны пересекаться

create function usage()
returns trigger as $$
declare times int;
begin
    times := count(*) from Schedule where NEW.Start_W between Start_W and End_W and Box = NEW.Box;
    if times > 0 then
    return NULL;
end if;
    times := count(*) from Schedule where NEW.End_W between Start_W and End_W and Box = NEW.Box;
    if times > 0 then
    return NULL;
    end if;
return NEW;
end;
$$ language plpgsql;

drop trigger check_usage on Schedule;
create trigger check_usage before insert on Schedule for each row execute procedure usage();

create table Master(
    Name varchar(100) primary key ,
    Specialty varchar(50) not null ,
    Qualification varchar(50) not null ,
    Experience_in_years int check ( Experience_in_years >= 0 ),
    Previous_Jobs varchar(500),
    Rating int not null check ( Rating >= 0 and Rating <=10),
    Salary int not null check ( Salary >= 0 )
);

insert into Master values ('Петров Петр', 'Мойщик', 'Мойщик-стажер', 0, '-', 4, 15000);
insert into Master
values ('Букин Геннадий', 'Директор', '-', 10, 'завод автозапчастей', 9, 100000);
insert into Master
values ('Иванов Иван', 'Автоэлектрик', '1 разряд', 5, 'автосервис Мечта', 7, 25000);
insert into Master
values ('Михайлов Михаил', 'Автомаляр', '1 разряд', 7, 'автосервис Тачка', 10, 30000);
insert into Master
values ('Сергеев Сергей', 'Менеджер по запчастям', '-', 2, 'склад при заводе автозапчастей', 6, 40000);
insert into Master
values ('Антонов Антон', 'Автослесарь', '3 разряд', 0.5, 'автосервис Мечта', 3, 30000);
insert into Master
values ('Никитин Никита', 'Парковщик', '-', 0.5, 'отель Суперстар', 4, 15000);
insert into Master
values ('Олегов Олег', 'Автодаигност', '2 разряд', 3, 'автосервис Дубай', 7, 50000);
insert into Master
values ('Александров Александр', 'Шиномонтажник', '1 разряд', 4, 'автосервис Пушка', 8, 30000);
insert into Master
values ('Егоров Егор', 'Автожестянщик', '2 разряд', 6, 'автосервис Дубай', 3, 25000);

insert into Master values ('Родионов Родион', 'Администратор', '-', 3, 'автосалон Лада', 6, 40000);
select * from Master;


create table Client(
    Name varchar(100) primary key ,
    Type_of_insurance varchar(100),
    Rating int not null check( Rating >= 0 and Rating <=10)
);

insert into Client values ('Смирнов Кирилл', 'осаго', 5),
                          ('Кузнецов Петр', 'осаго', 7),
                          ('Попов Ренат', 'каско', 2),
                          ('Новикова Елизавета', 'каско', 10),
                          ('Семенов Семен', 'каско', 6),
                          ('Богланов Ратмир', 'осаго', 3);

create table Works(
  Name varchar(100) primary key ,
  Duration int not null check ( Duration >= 0 ),
  Min_Cost int not null check ( Min_Cost >= 0 ),
  Max_Cost int not null check ( Max_Cost >= 0 ),
  Spec_equipment varchar(500)
);
insert into Works values ('Диагностика двигателя', 3, 3000, 5000, 'оборудование для диагностики'),
                         ('Замена масла', 1, 2000, 2500, '-'),
                         ('Покраска кузова', 5, 15000, 30000, 'покрасочное оборудование'),
                         ('Мойка автомобиля', 0.5, 500, 1000, 'мойка'),
                         ('Детали на заказ', 0, 0, 100000, '-'),
                         ('Шиномонтаж', 2, 8000, 10000, 'подъемник'),
                         ('Развал-схождение', 1.5, 3000, 5000, 'оборудование для диагностики'),
                         ('Ремонт тормозной системы', 4, 8000, 10000, 'подъемник'),
                         ('Восстановление корпуса после аварии', 3, 10000, 20000, '-');

create table Car(
    Number varchar(10) primary key check (length(Number) < 7 ),
    Year_of_release int check ( Year_of_release <= 2020 ),
    Type_of_engine varchar(50) not null ,
    Previous_owner varchar(100) not null
);
insert into Car values ('а145тр', 2003, 'инжекторный', 'Голубев Владимир'),
                       ('а321уф', 2013, 'инжекторный', 'Павлов Дмитрий'),
                       ('м185лг', 2009, 'карбюраторный', 'Морозов Антон'),
                       ('и349от', 2017, 'дизельный', 'Лебедева Иванна'),
                       ('т426мп', 2012, 'карбюраторный', 'Виноградов Анастас'),
                       ('о800вб', 2018, 'дизельный', 'Габрелян Аветик');


create table Box(
  Type int not null check ( Type >= 0 ),
  Number int primary key check ( Number >= 0 ),
  Spec_equipment varchar(500)
);
insert into Box values (1, 1, 'мойка'),
                       (1, 2, 'мойка'),
                       (2, 3, 'подъемник'),
                       (2, 4, 'подъемник'),
                       (2, 5, 'покрасочное оборудование');
insert into Box values (2, 6, 'оборудование для диагностики');



create table Schedule(
    Master varchar(100) references Master(Name),
    Client varchar(100) not null references Client(Name),
    Box int references Box(Number) check ( Box >= 0 ),
    Car varchar(10) references Car(Number) check(length(Car) < 7 ),
    Cost int not null check ( Cost >= 0 ),
    Start_W time  ,
    End_W time  ,
    Work varchar(100) references Works(Name)
);
drop table Schedule;

insert into Schedule  values ('Петров Петр', 'Смирнов Кирилл', 2, 'а145тр', 600, '12:00:00', '12:30:00', 'Мойка автомобиля');
insert into Schedule  values ('Егоров Егор', 'Попов Ренат', 3, 'а321уф', 13000, '17:00:00', '18:30:00', 'Восстановление корпуса после аварии');

insert into Schedule  values ('Михайлов Михаил', 'Попов Ренат', 5, 'и349от', 19800, '15:00:00', '16:30:00', 'Покраска кузова');

insert into Schedule  values ('Петров Петр', 'Новикова Елизавета', 1, 'т426мп', 500, '12:30:00', '13:00:00', 'Мойка автомобиля');
insert into Schedule  values ('Олегов Олег', 'Богланов Ратмир', 6, 'о800вб', 4600, '11:09:00', '14:30:00', 'Диагностика двигателя');
insert into Schedule  values ('Антонов Антон', 'Кузнецов Петр', 4, 'м185лг', 3000,'17:00:00', '18:25:00', 'Развал-схождение');
insert into Schedule  values ('Олегов Олег', 'Кузнецов Петр', 6, 'о800вб', 4600, '11:09:00', '14:30:00', 'Диагностика двигателя');

