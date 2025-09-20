create database t01_library;

create table public.author(
id serial primary key,
lastname varchar(50) not null,
firstname varchar(50)not null);

create table public.publishing_house(
id serial primary key,
title varchar(50) not null,
city varchar(50));

create table public.book(
id serial primary key,
title varchar(50)not null,
id_author integer not null references public.author(id),
id_publishing_house integer not null references public.publishing_house(id),
version integer,
year_of_public integer,
circulation integer);

create table public.reader(
id_reader_ticket integer primary key,
lastname varchar(30) not null,
firstname varchar(30) not null,
birthday varchar(12),
gender varchar(1) not null);

CREATE TYPE book_state AS ENUM ('отличное', 'хорошее', 'удовлетворительное', 'ветхое', 'утеряна');
CREATE type book_status AS ENUM ('в наличии', 'выдана', 'забронирована');

create table public.book_instance(
inventory_number integer primary key,
book_info integer not null references public.book(id),
state book_state not null,
status book_status not null,
location varchar(100) not null);

create table  public.issuance(
fk_reader_ticket integer not null references public.reader(id_reader_ticket),
fk_inventory_num integer not null references public.book_instance(inventory_number),
date_time_issue varchar(20) not null,
expected_return_date varchar(12) not null,
actual_return_date varchar(12));

create table public.booking(
booking_num serial primary key,
fk2_reader_ticket integer not null references public.reader(id_reader_ticket),
book_info integer not null references  public.book(id),
date_time varchar(20) not null);


