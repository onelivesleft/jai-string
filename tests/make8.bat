@echo off
echo Set to false
pause
jai test8.jai -release
copy test8.exe test8slow.exe /y
echo Set to true
pause
jai test8.jai -release
copy test8.exe test8fast.exe /y
