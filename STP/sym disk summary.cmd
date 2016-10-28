@echo off
if EXIST "%CD%\symapi_db.bin" cmd /K "set SYMCLI_OFFLINE=1 & set SYMCLI_DB_FILE=%CD%\symapi_db.bin" & echo "%CD%\symapi_db.bin ready to query."
if NOT EXIST "%CD%\symapi_db.bin" echo No symapi_db.bin file found in %CD% directory & pause


symdisk list -dskgrp_summary | sed "s/  */ /g" | grep -e"^ [0-9]" | cut -d" " -f4,5,6,7 | sed "s/0 190782/200GB/" |sed "s/15000 418710/15k 450GB/" | sed "s/7200 953870/7.2k 1TB/" | sed "s/15000 558281/15k 600GB/"

symdisk list -hotspare | sed "s/  */ /g" | grep -v "Total" | grep -v "\-\-\-\-" | cut -d" " -f6,8 | sed "s/C01TMSK 953870/SATA 7.2k 1TB/" | sed "s/EGC4515 418710/FC 15k 450GB/" | sed "s/HCC4515 418710/FC 15k 450GB/" | sed "s/HCC6015 558281/FC 15k 600GB/" | sed "s/N01THGK 953870/SATA 7.2k 1TB/" | sed "s/N01TMOO 953870/SATA 7.2k 1TB/" | sed "s/STC0200 190782/EFD 200GB/"  | sort

pause