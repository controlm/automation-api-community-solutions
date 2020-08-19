@echo off

echo Adding user defined in %1%
ctm config authorization:user::add %1%

