#This script will process ORDERS. One laptop equals one order, and the ORDER is uniquely identifiable and corresponds to website order.
#It takes into consideration that we are under a QubesOS AppVM:
# - ch341 external programmer is already attached to this AppVM
# - That sdcard to be prepared is attached to this AppVM
#   - That ISO images to be copied to the SDCARD are under ~/Downloads/OEM_SDCARD_PUBLIC
#   - That GitLabCI dowloaded QubesOS_Certified branch artifact is dowloaded and stored under
#     - TODO: insert glue to download latest verified GitLabCi build's artifact, now statically
if [ ! -e ./OEM_SDCARD_PUBLIC ]; then
  mkdir -p OEM_SDCARD_PUBLIC
  echo "Download ISOs and their accompanying signature files and store them under ./OEM_SDCARD_PUBLIC directory here."
  exit 1
fi

if [ ! -e ./PrivacyBeastX230-QubesOS-Certified-ROMS ]; then 
  mkdir -p ./PrivacyBeastX230-QubesOS-Certified-ROMS
fi

#Download latest stable PrivacyBeastX230 stable ROM
if [ ! -e ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-flash-libremkey.rom ] || [ ! -e ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-libremkey.rom ]; then
  wget https://gitlab.com/tlaurion/heads/-/jobs/312958561/artifacts/raw/build/x230-flash-libremkey/x230-flash-libremkey.rom?inline=false?job=build -O ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-flash-libremkey.rom
  wget https://gitlab.com/tlaurion/heads/-/jobs/312958561/artifacts/raw/build/x230-flash-libremkey/hashes.txt?inline=false?job=build -O ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-flash-libremkey.txt
  grep -q $(sha256sum ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-flash-libremkey.rom | awk -F " " {'print $1'}) ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-flash-libremkey.txt && echo sha256sum matches|| ( echo sha256sum mismatches && exit 1)

  wget https://gitlab.com/tlaurion/heads/-/jobs/312958349/artifacts/raw/build/x230-libremkey/coreboot.rom?inline=false?job=build -O ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-libremkey.rom
  wget https://gitlab.com/tlaurion/heads/-/jobs/312958349/artifacts/raw/build/x230-libremkey/hashes.txt?inline=false?job=build -O ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-libremkey.txt
  grep -q $(sha256sum ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-libremkey.rom | awk -F " " {'print $1'}) ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-libremkey.txt && echo sha256sum matches|| (echo sha256sum mismatches && exit 1)
fi


while true; do
  echo "Enter ORDER number associated with hardware to prepare:"
  read ORDER
  
  if [ ! -e ./top.rom ] && [ ! -e $ORDER/top.rom ]; then
    echo -e "Place clip to top SPI flash chip and press enter\n"
    read

    TOP_BACKEDUP_AND_FLASHED=0
    while [ $TOP_BACKEDUP_AND_FLASHED != 1 ]; do
      echo "Launching ./subscripts/top.sh script"
      ./subscripts/top_MX25L3273E.sh  || ./subscripts/top_N25Q0323E.sh
      if [ $? -eq 0 ]; then
        TOP_BACKEDUP_AND_FLASHED=1
        echo "Backup and flashing of top SPI flash successful."
      fi
    done
  else
    echo "top.rom was found. If this is artifact of a prior unfinished backup, you might want to CTRL-C this and cleanup before continuing..."
    echo "Else, type enter to continue with this order!"
    read
  fi

  if [ ! -e ./bottom.rom ] && [ ! -e $ORDER/bottom.rom ]; then
    echo -e "Change clip to bottom SPI flash chip and press enter\n"
    read

    BOTTOM_BACKEDUP_AND_FLASHED=0
    while [ $BOTTOM_BACKEDUP_AND_FLASHED != 1 ]; do
      ./subscripts/bottom_EN25QH64.sh  || ./subscripts/bottom_MX25L6405.sh || ./subscripts/bottom_N25Q0643E.sh 
      if [ $? -eq 0 ]; then
        BOTTOM_BACKEDUP_AND_FLASHED=1
      fi
    done
  else
    echo "bottom.rom was found. If this is artifact of a prior unfinished backup, you might want to CTRL-C this and cleanup before continuing..."
    echo "Else, type enter to continue with this order!"
    read
  fi

  
  mkdir -p $ORDER > /dev/null 2>&1 || true
  mv *.rom $ORDER/ > /dev/null 2>&1 || true

  echo "Provisioning random secrets to be stored under sdcard /oem-provisioning..."
  ./subscripts/generate_diceware-eom-provisioning.sh

  while [ ! -e $1 ]; do
    echo "Make sure sdcard/usb drive was to this AppVM and is available into device: $1"
  done
  ./subscripts/InsurgoSDCARD_prep.sh "$1" "$ORDER"

done    
