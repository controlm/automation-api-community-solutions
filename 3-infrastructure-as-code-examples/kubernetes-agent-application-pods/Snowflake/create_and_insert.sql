create or replace database sf_tuts;

select current_database(), current_schema();

create or replace table emp_basic (
  first_name string ,
  last_name string ,
  email string ,
  streetaddress string ,
  city string ,
  start_date date
  );
  
create or replace warehouse sf_tuts_wh with
  warehouse_size='X-SMALL'
  auto_suspend = 180
  auto_resume = true
  initially_suspended=true;

  select current_warehouse();

put file://C:\temp\employees0*.csv @sf_tuts.public.%emp_basic;

list @sf_tuts.public.%emp_basic;

copy into emp_basic
  from @%emp_basic
  file_format = (type = csv field_optionally_enclosed_by='"')
  pattern = '.*employees0[1-5].csv.gz'
  on_error = 'skip_file';

select * from emp_basic;

insert into emp_basic values
  ('Clementine','Adamou','cadamou@sf_tuts.com','10510 Sachs Road','Klenak','2017-9-22') ,
  ('Marlowe','De Anesy','madamouc@sf_tuts.co.uk','36768 Northfield Plaza','Fangshan','2017-1-26');

select email from emp_basic where email like '%.uk';

select first_name, last_name, dateadd('day',90,start_date) from emp_basic where start_date <= '2017-01-01';
