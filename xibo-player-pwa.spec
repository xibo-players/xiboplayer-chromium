%global debug_package %{nil}

Name:           xibo-player-pwa
Version:        1.0.0
Release:        1%{?dist}
Summary:        Xibo PWA Digital Signage Player Kiosk
License:        AGPLv3
URL:            https://github.com/tecman-solutions/xibo-players
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

# Browser: prefer chromium, allow google-chrome-stable as alternative
Requires:       (chromium or google-chrome-stable)
Requires:       xdg-utils
Requires:       systemd
# X11 utilities for screen blanking control
Recommends:     xdotool
Recommends:     xset

%description
Xibo PWA Digital Signage Player for kiosk deployments on Fedora, RHEL, and
CentOS Stream. Launches a fullscreen browser pointed at a Xibo CMS PWA player
URL, with automatic restart and screen-blanking prevention.

Designed for headless digital signage displays that boot directly into the
player interface without user interaction.

%prep
# No source archive to unpack when building locally; files are placed directly.
# When building from tarball, standard %setup would go here.

%build
# Nothing to build — this is a noarch package of scripts and config files.

%install
rm -rf %{buildroot}

# Launch script
install -D -m 0755 %{_sourcedir}/opt/xibo-player/launch-kiosk.sh \
    %{buildroot}/opt/xibo-player/launch-kiosk.sh

# Configuration
install -D -m 0644 %{_sourcedir}/etc/xibo-player/config.env \
    %{buildroot}%{_sysconfdir}/xibo-player/config.env

# Systemd user service
install -D -m 0644 %{_sourcedir}/usr/lib/systemd/user/xibo-player-kiosk.service \
    %{buildroot}%{_userunitdir}/xibo-player-kiosk.service

# Desktop entry
install -D -m 0644 %{_sourcedir}/usr/share/applications/xibo-player.desktop \
    %{buildroot}%{_datadir}/applications/xibo-player.desktop

%files
%dir /opt/xibo-player
/opt/xibo-player/launch-kiosk.sh
%config(noreplace) %{_sysconfdir}/xibo-player/config.env
%{_userunitdir}/xibo-player-kiosk.service
%{_datadir}/applications/xibo-player.desktop

%post
# Reload systemd user daemon for all active sessions so the service is visible.
# This runs as root during RPM install, so we broadcast to all logged-in users.
echo ""
echo "============================================================"
echo " Xibo PWA Player installed successfully."
echo ""
echo " Next steps:"
echo "   1. Edit /etc/xibo-player/config.env"
echo "      Set CMS_URL to your Xibo CMS PWA player URL."
echo ""
echo "   2. Enable auto-start (run as the kiosk user):"
echo "      systemctl --user enable --now xibo-player-kiosk.service"
echo ""
echo "   3. To start manually:"
echo "      /opt/xibo-player/launch-kiosk.sh"
echo "============================================================"
echo ""

%preun
# On uninstall (not upgrade), remind to disable the service
if [ "$1" -eq 0 ]; then
    echo ""
    echo "NOTE: Remember to disable the kiosk service for each user:"
    echo "  systemctl --user disable --now xibo-player-kiosk.service"
    echo ""
fi

%changelog
* Fri Feb 14 2026 TecMan Solutions <dev@tecman.cat> - 1.0.0-1
- Initial RPM release
- Chromium and Firefox kiosk mode support
- Systemd user service for auto-start
- Wayland and X11 screen blanking prevention
- Configurable CMS URL and browser flags
