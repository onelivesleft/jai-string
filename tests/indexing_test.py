import time, sys

haystack = open("data/shakespeare.jai").read().split("__WILLIAM\n")[1]
needle = " and "

times = 10

index = haystack.find(needle)
while index >= 0:
    index = haystack.find(needle, index + 1)


total_checksum = 0
t = time.time()
for x in range(times):
    index = haystack.find(needle)
    checksum = 0
    while index >= 0:
        checksum = checksum ^ index
        index = haystack.find(needle, index + 1)
    total_checksum += checksum
delta = time.time() - t
print(total_checksum, delta)
