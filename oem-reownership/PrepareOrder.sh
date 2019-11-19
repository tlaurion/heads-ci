#This script will process ORDERS. One laptop equals one order, and the ORDER is uniquely identifiable and corresponds to website order.
#It takes into consideration that we are under a QubesOS AppVM:
# - ch341 external programmer is already attached to this AppVM
# - That sdcard to be prepared is attached to this AppVM
#   - That ISO images to be copied to the SDCARD are under ~/Downloads/OEM_SDCARD_PUBLIC
#   - That GitLabCI dowloaded QubesOS_Certified branch artifact is dowloaded and stored under
#     - TODO: insert glue to download latest verified GitLabCi build's artifact, now statically
if [ -z $1 ]; then
  clear
  echo -e "\nPlease launch this script as:\n\n$0 /dev/sda\nWhere sda is the sdcard drive expected to be provisioned with:\n 1-Encrypted partition with disk passphrase specified under ./oem.information: original roms, oem-provisioning file\n 2-ISOs and accompanying signature files..."
  echo -e "\nNote that external disks in QubesOS are detected as sda sdb sdc, while internal disks are xvda xvdb xvdc.."
  echo -e "You can safely pass /dev/sda argument to this script, as long as no external drive is passed to this AppVM."
  exit 1
fi

clear

#We export OEM provisioning information
source ./oem.information
#We extract Disk Recovery Key provisioned in oem.information so it is usable as a file in SdCardPrep script
echo -e $oem_luks_actual_Disk_Recovery_Key > ./OEM_SSD_sdcard_Disks_Recovery_Key_Passphrase 

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
 
  #Create dir if not existing
  mkdir -p $ORDER > /dev/null 2>&1 || true

  #TODO: change script to not depend on ifdtool, considering x230-libremkey would produce 12Mb image splitted in 4Mb and 8Mb image with shrinked IFD and ME taken from blob directory
  if [ ! -e $ORDER/top.rom ]; then
    clear
    echo -e "!ATTENTION!"
    echo -e "Make sure that all electricity sources are disconnected from hardware to reprogram before going further." 
    echo -e "Make sure that the reprogrammer clip adaptor is connected through the closest holes from the reprogrammer's laptop."
    echo -e "Make sure that the reprogrammer clip adaptor is connected to the reprogrammer with text being readable from the reprogramming laptop."
    echo -e "Make sure that the red wire leaving the reprogrammer and going to the clip is on the right side of the reprogrammer."
    echo -e "Make sure that the red wire of your reprogrammer clip is alligned with the dot on SPI CHIP (8th pin of the SPI chip)\n\n"
    echo -e "Press the Enter key to continue when ready..."
    read
    clear
    echo -e "Place programmer clip on top SPI flash chip on laptop to reprogram..."
    echo -e "This will attempt to access known SPI chips in a loop until detected.\n"
    echo -e "It requires the ch_431a programmer to be assigned to this AppVM first."
    echo -e "Check the screen between SPI chip programmer's clip reajustments. Flashrom will pick up when SPI flash chip is detected.\n"
    echo -e "\nPossible errors:"
    echo -e "...Couldn't open device 1a86:5512....: Verify reprogrammer is connected and passed to this AppVM."
    echo -e "Others: You are not clipping the SPI chip correcty to the SPI chip. Make sure the metal wires are all connecting and reclip firmly until flashrom picks up."
    echo -e "\nClip replacement\nYou want to limit sideways movements once the clip is in place else clip wear will occur.\n Pinch clip firmly and retry. If the clip is unstable, replace the clip and retry."
    echo -e "\n\nPress the enter key to continue when ready...\n"
    read

    TOP_BACKEDUP_AND_FLASHED=0
    while [ $TOP_BACKEDUP_AND_FLASHED != 1 ]; do
      #As of right now, the following top SPI_CHIPS have been seen in the while.
      for SPI_CHIP in "MX25L3273E" "N25Q032..3E"; do
        echo -e "\nBackuping top $SPI_CHIP SPI flash chip into ./$ORDER/top.rom...\n" \
          && sudo flashrom -r ./$ORDER/top.rom --programmer ch341a_spi -c $SPI_CHIP \
        && echo -e "\nVerifying top $SPI_CHIP SPI flash chip...\n" \
          && sudo flashrom -v ./$ORDER/top.rom --programmer ch341a_spi -c $SPI_CHIP \
        && echo -e "\nFlashing top $SPI_CHIP SPI flash chip...\n" \
          && sudo flashrom -w  ./PrivacyBeastX230-QubesOS-Certified-ROMS/x230-flash-libremkey.rom  --programmer ch341a_spi -c $SPI_CHIP
      done
      if [ $? -eq 0 ]; then
        TOP_BACKEDUP_AND_FLASHED=1
        echo -e "\nBackup and flashing of top SPI flash successful.\n"
      fi
    done
  else
    echo -e "\n$ORDER/top.rom was found. If this is artifact of a prior unfinished backup, you might want to CTRL-C this and cleanup before continuing..."
    echo "Else, type enter to continue with this order!"
    read
  fi

  if [ ! -e $ORDER/bottom.rom ]; then
    echo -e "\nChange clip to bottom SPI flash chip and press Enter...\n"
    read
    
    #As of right now, the following bottom SPI_CHIPS have been seen in the while.
    for SPI_CHIP in "EN25QH64" "MX25L6405" "N25Q064..3E"; do
      echo "Backuping bottom $SPI_CHIP SPI flash chip into $ORDER/bottom.rom..." \
          && sudo flashrom -r ./$ORDER/bottom.rom --programmer ch341a_spi -c $SPI_CHIP \
      && echo "Verifying bottom $SPI_CHIP SPI flash chip..." \
        && sudo flashrom -v ./$ORDER/bottom.rom --programmer ch341a_spi -c $SPI_CHIP \
      && echo "Unlocking ROM descriptor..." \
        && /home/user/heads/build/coreboot-4.8.1/util/ifdtool/ifdtool -u ./$ORDER/bottom.rom \
      && echo "Neutering+Deactivating ME..." \
        && python /home/user/me_cleaner/me_cleaner.py -r -t -d -S -O ./$ORDER/cleaned_me.rom \
        ./$ORDER/bottom.rom.new --extract-me ./$ORDER/extracted_me.rom \
      && echo "Flashing back Neutered+Deactivated ME in bottom $SPI_CHIP SPI flash chip..." \
        && sudo flashrom -w ./$ORDER/cleaned_me.rom --programmer ch341a_spi -c $SPI_CHIP
    done
    BOTTOM_BACKEDUP_AND_FLASHED=0
    while [ $BOTTOM_BACKEDUP_AND_FLASHED != 1 ]; do
      
      if [ $? -eq 0 ]; then
        BOTTOM_BACKEDUP_AND_FLASHED=1
      fi
    done
  else
    echo -e "\n$ORDER/bottom.rom was found. If this is artifact of a prior unfinished backup, you might want to CTRL-C this and cleanup before continuing..."
    echo "Else, type enter to continue with this order!"
    read
  fi

  echo -e "\nProvisioning random secrets to be stored under sdcard /oem-provisioning..."
  ./subscripts/generate_diceware-eom-provisioning.sh

  while [ ! -e $1 ]; do
    echo "Make sure sdcard/usb drive was to this AppVM and is available into device: $1"
  done
  ./subscripts/InsurgoSDCARD_prep.sh "$1" "$ORDER"

done    
