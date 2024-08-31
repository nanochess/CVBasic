./cvbasic --ti994a $1.bas $1.a99
../../xdt99/xas99.py -R $1.a99 -L $1.lst
../../xdt99/xdm99.py -X sssd work.dsk -a $1.obj -f df80
