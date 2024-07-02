# Arch installer and Hyprland config

This repo contains some personal config files that I've used to install Arch 
with both Hyprland and KDE Plasma 6 working without conflicts of theming. It's
not necessarily files that can replicate my entire setup but rather files that
I'd like to keep a backup of in case I need to reinstall.

# Arch installer

**This installer does not (yet) contain the install of Hyprland**

This is just the installer to create a very minimal Arch installation with
Btrfs, LUKS2 encryption full-disk encryption headers, Secure Boot management
over Unified Kernel Images (safer than having kernel and initramfs files
separate allowing initramfs files or bootloader configs to be possibly changed).

# Hyprland

The repository also contains some Hyprland config files. The main goal with
these were to make use of the KDE XDG Desktop Portal to allow uniform
styling of Qt6 across the KDE Plasma 6 DE and Hyprland.

*possibly still doesn't style dark mode for GTK applications, but I believe
the gsettings are changed by KDE upon Plasma 6 install and theme configuration*

In addition to styling, it'll also prefer the KDE file picker (aka File Chooser)
in Hyprland.
