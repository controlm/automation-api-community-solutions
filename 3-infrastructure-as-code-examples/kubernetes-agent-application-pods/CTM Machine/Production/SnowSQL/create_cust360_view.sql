create or replace database cust360_view_db;

select current_database(), current_schema();

create or replace table cust_basic (
  first_name string ,
  last_name string ,
  email string ,
  streetaddress string ,
  city string ,
  start_date date
  );
  
create or replace warehouse cust360_view_wh with
  warehouse_size='X-SMALL'
  auto_suspend = 180
  auto_resume = true
  initially_suspended=true;

  select current_warehouse();