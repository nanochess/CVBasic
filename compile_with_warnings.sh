# Compile CVBasic with Clang warnings, except some too twisted
gcc -Weverything -Wno-sign-conversion -Wno-implicit-int-conversion -Wno-switch-enum -Wno-padded -Wno-poison-system-directories -Wno-shadow cvbasic.c node.c -o cvbasic
