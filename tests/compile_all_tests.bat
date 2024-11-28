jai -quiet -import_dir .. allocator_test.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. indexing_test.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. normal_test.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. simd_test.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. strings_bug.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test10.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test11.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test5.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test6.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test7.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test8.jai
@if NOT ["%errorlevel%"]==["0"] goto end

jai -quiet -import_dir .. test9.jai
@if NOT ["%errorlevel%"]==["0"] goto end

:end