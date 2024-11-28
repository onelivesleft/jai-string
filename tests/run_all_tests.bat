allocator_test.exe
@if NOT ["%errorlevel%"]==["0"] goto end

indexing_test.exe
@if NOT ["%errorlevel%"]==["0"] goto end

normal_test.exe
@if NOT ["%errorlevel%"]==["0"] goto end

simd_test.exe
@if NOT ["%errorlevel%"]==["0"] goto end

strings_bug.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test10.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test11.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test5.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test6.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test7.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test8.exe
@if NOT ["%errorlevel%"]==["0"] goto end

test9.exe
@if NOT ["%errorlevel%"]==["0"] goto end

:end