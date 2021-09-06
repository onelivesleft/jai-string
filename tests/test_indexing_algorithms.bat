@echo off
..\tools\index_profile.exe -t data\shakespeare.jai "/*"
if NOT ["%errorlevel%"]==["0"] goto end

..\tools\index_profile.exe -t data\shakespeare.jai "__WILLIAM\n"
if NOT ["%errorlevel%"]==["0"] goto end



:end
