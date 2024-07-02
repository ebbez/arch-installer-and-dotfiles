#!/bin/bash

echo "This is a personal installer without guarantees or safety-features built-in.
It will wipe your disk, encrypt the Linux (root) partition, create Secure Boot keys and install some default packages
while configuring it in a way so the initramfs or the boot loader can't be altered unless hacker gains explicit root privileges."
read -p "Are you sure you want to continue? (press ctrl-c to abort! yes/no-confirmations are not built-in)"




# PARTITIONING
echo "
Partition disk
> Will wipe and set disk partition table type to GPT
Partition #1: 1GB EFI partition
Partition #2: Remaining/leftover space for Linux partition
"
echo
read -p "Disk (include p if nvme e.g. '/dev/nvme0n1p'): " disk

# The zeroes in the `sgdisk` command all mean default values.
# For the --new it means "<next number>:<first available sector on disk>:<last available sector on disk>"
# For the --typecode it means the newest partition (number)

# Clear entire disk partition table
sgdisk --zap-all $disk
# Add new 1GB EFI partition to clean partition table
sgdisk $disk --new 0:0:+1G --typecode 0:ef00
# Add new Linux partition to clean partition table. Assign all the leftover space to it.
sgdisk $disk --new 0:0:0 --typecode 0:8300




# FORMATTING
# Format EFI partition
echo "Format ${disk}1 with FAT32 for EFI"
mkfs.fat -F32 ${disk}1

# Encrypt Linux partition
echo "Format ${disk}2 with LUKS2 for encryption"
cryptFail=0
until cryptsetup luksFormat ${disk}2
do
    echo "LUKS format unsuccesful. Trying again.
    "

    cryptFail=$(($cryptFail+1))
    if (( $cryptFail > 3 )); then
        echo "Configuring the LUKS container failed 3 times, aborting install"
        exit 1
    fi
done

# Open encrypted LUKS container on Linux partition
echo "Opening ${disk}2 to get decrypted partition mapped to /dev/mapper/system"
until cryptsetup open ${disk}2 system
do
    echo "Opening LUKS container unsuccesful. Trying again.
    "

    cryptFail=$(($cryptFail+1))
    if (( $cryptFail > 3 )); then
        echo "Configuring the LUKS container failed 3 times, aborting install"
        exit 1; 
    fi
done

# Format LUKS container with Btrfs
echo "Format /dev/mapper/system with Btrfs"
mkfs.btrfs /dev/mapper/system




# BTRFS CONFIGURATION (SUBVOLUMES & SWAPFILE)
# Declare subvolumes and their respective mounting points as an associative Bash array.
subvolumes=(@ @home @snapshots @pkg @log @tmp @swap)
subvolumes_mounts=(/ /home /.snapshots /var/cache/pacman/pkg /var/log /var/tmp /swap)

# Mount top-level Btrfs subvolume
echo "Mounting Btrfs top-level subvolume to create subvolumes"
mount /dev/mapper/system /mnt

# Create subvolumes to keep separate when reinstalling the operating system or snapshotting
# (When taking snapshots and reverting back, you would probably not want to revert back the @home folder, or take snapshots of cached or logged data/files.)
echo "Creating subvolumes"
for subvol in "${subvolumes[@]}"; do
    btrfs subvolume create /mnt/$subvol
done

# Unmounting the top-level Btrfs subvolume to allow mounting all the separate subvolumes to the root /mnt mounting point
echo "Unmounting Btrfs partition"
umount /mnt





# MOUNTING
echo "Mounting subvolumes with zstd compression and no access time tracking"
for subvol in "${!subvolumes[@]}"; do
    mount --options noatime,nodiratime,x-mount.mkdir,compress=zstd,subvol=${subvolumes[$subvol]} /dev/mapper/system /mnt${subvolumes_mounts[$subvol]}
done
mount --options x-mount.mkdir ${disk}1 /mnt/efi




# ARCH INSTALLATION & CONFIGURATION
PACKAGES="base base-devel linux linux-firmware btrfs-progs cryptsetup dhcpcd sbctl neovim efibootmgr git man"
echo "Installing Arch with $PACKAGES"
pacstrap /mnt $PACKAGES

echo "Generating fstab file to mount"
genfstab -U /mnt >> /mnt/etc/fstab # -U means 'Use UUIDs for source identifiers'

read -p "Size of swapfile (e.g. '8G' or '4096M'): " swapSize
arch-chroot /mnt btrfs filesystem mkswapfile --size $swapSize --uuid clear /swap/swapfile
echo "
/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

echo
read -p "Hostname [archmachine]: " hostname
hostname=${hostname:-archmachine}
read -p "Locale [en_US.UTF-8]: " locale
locale=${locale:-en_US.UTF-8}

echo "Configuring hostname in /etc/hostname and /etc/hosts"
echo "$hostname" > /mnt/etc/hostname
echo -e "127.0.0.1\tlocalhost\t$hostname 
::1\t\tlocalhost\t$hostname" >> /mnt/etc/hosts

echo "Configuring locale"
echo "$locale UTF-8" >> /mnt/etc/locale.gen
echo "LANG=$locale" >> /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# Configuring and producing of the UKI with mkinitcpio
echo "Configuring UKI"
mkdir /mnt/etc/cmdline.d
# Create kernel command line parameters to find encrypted partition, decrypt it, and find the root subvolume
echo "cryptdevice=UUID=$(blkid -s UUID -o value ${disk}2):system root=/dev/mapper/system rootflags=rw,noatime,nodiratime,compress=zstd,subvol=@" > /mnt/etc/cmdline.d/root.conf

# Commenting out the generation of default image files (often used by bootloaders)
sed -i '/default_image=/s/^/#/' /mnt/etc/mkinitcpio.d/linux.preset
sed -i '/fallback_image=/s/^/#/' /mnt/etc/mkinitcpio.d/linux.preset

# Uncommenting the generation of fallback UKI
sed -i '/fallback_uki=/s/^#//' /mnt/etc/mkinitcpio.d/linux.preset
# Adding a new line for generation of default UKI as the default UKI should be generated to /efi/EFI/Boot/bootx64 so it is recognized as the disk's default boot loader
# (useful for booting on portable drives where the UEFI boot entries aren't added to the device)
sed -i '/#default_uki=/a default_uki=\"/efi/EFI/Boot/bootx64.efi\"' /mnt/etc/mkinitcpio.d/linux.preset

# Adding encryption and Btrfs hook to mkinitcpio
sed -i '/^HOOKS=/s/block/encrypt btrfs block/' /mnt/etc/mkinitcpio.conf

# Creating directories in the Efi System Partition (ESP) for the UKI's (the .efi files) to reside in so they can be loaded at boot (/efi is unencrypted)
mkdir -p /mnt/efi/EFI/Linux
mkdir /mnt/efi/EFI/Boot

# Creating Secure Boot keys to sign EFI binaries created by mkinitcpio
arch-chroot /mnt sbctl create-keys

# Generate UKI files and sign them automatically
arch-chroot /mnt mkinitcpio -P

# Deleting the initramfs files in /boot (generated by pacstrap) because those are not accessible for any bootloader anyways (/boot is encrypted)
rm /boot/initramfs-linux*

# Add boot entries in UEFI boot
efibootmgr --create --disk $disk --part 1 --label "Arch Linux (fallback)" --loader '\EFI\Linux\arch-linux-fallback.efi' --unicode
efibootmgr --create --disk $disk --part 1 --label "Arch Linux" --loader '\EFI\Boot\bootx64.efi' --unicode
# (The last boot entry isn't necessarily needed but otherwise the fallback would take priority over the default efi of the disk because it was added last)

# Default admin user creation
echo "Creating default (admin) user account:"
read -p "Username: " username

arch-chroot /mnt useradd $username -m -G wheel
arch-chroot /mnt passwd $username

# Uncomment wheel group in sudoers file to allow user to use sudo
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /mnt/etc/sudoers

# Enable dhcpcd service for automatic internet connection after restart
arch-chroot /mnt systemctl enable dhcpcd

echo
read -p "Restart the pc? (y/n): " configure

if [[ $configure =~ ^[Yy]$ ]]; then
    clear
    echo "Do not forget to enroll the secure boot keys after reboot with 'sbctl enroll-keys -m' (leave -m if you do not want to enroll with Microsoft Platform Keys)!"
    sleep 15
    reboot
else
    arch-chroot /mnt
    echo
    echo "Do not forget to enroll the secure boot keys after reboot with 'sbctl enroll-keys -m' (leave -m if you do not want to enroll with Microsoft Platform Keys)"
    sleep 5
fi
