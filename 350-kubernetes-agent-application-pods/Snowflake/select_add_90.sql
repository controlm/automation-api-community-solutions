use database sf_tuts;
select first_name, last_name, dateadd('day',90,start_date) from emp_basic where start_date <= '2017-01-01';