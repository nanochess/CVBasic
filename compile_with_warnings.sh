# Compile CVBasic with Clang warnings, except some too twisted
gcc -Weverything -Wno-sign-conversion -Wno-implicit-int-conversion -Wno-switch-enum -Wno-padded -Wno-poison-system-directories -Wno-shadow cvbasic.c node.c driver.c cpu6502.c cpuz80.c -o cvbasic
