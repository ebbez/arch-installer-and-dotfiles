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

## Extra notes on installing Hyprland

### Kitty requires GTK3

The default terminal Kitty requires GTK3 to launch but for some reason it
is not a required dependency in the Arch package repository.

### To follow KDE style requires environment variable

This is already included in the given `hyperland.conf` file defined in the
line containing `env = QT_QPA_PLATFORMTHEME,kde`. This will follow
the KDE system settings application.

If you wish to use Qt6 Configuration Tool (qt6ct), you can change this line to
`nv = QT_QPA_PLATFORMTHEME,qt6ct`. This is in the case you aren't (planning on)
using the KDE Plasma 6 DE.

### Polkit

To start Hyprland you also need a Polkit to assign you a seat. This is also
one package on which the launching of Hyprland relies on, but for
some reason isn't required by the package in the Arch Repo.
(probably possible without but launching it on a from-scratch install didn't
work for me without it).

I've specified the use of the KDE authentication agent in the `hyprland.conf`
line: `exec-once = /usr/lib/polkit-kde-authentication-agent-1`.

### Scaling (except for xwayland/X11 applications)

My main monitor is 1440p on a 23,8" screen, which makes it a HiDPI screen in
my experience. To counter the high DPI I've included a 125% (fractional) scale.

Scaling xwayland applications sucks. It'll make them blurry because it'll just
stretch the application out from a smaller rendered resolution. Therefore it's
disabled in the configuration file. A `GDK_SCALE` environment variable could have
been used but in my experience it'll make application too large, so I'd rather
just deal with the tiny text.

