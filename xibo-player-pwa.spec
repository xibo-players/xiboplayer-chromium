%global debug_package %{nil}

Name:           xiboplayer-pwa
Version:        1.0.0
Release:        1%{?dist}
Summary:        Xibo PWA digital signage player (browser kiosk)

License:        AGPL-3.0-or-later
URL:            https://github.com/linuxnow/xibo_players
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

Requires:       (chromium or google-chrome-stable)
Requires:       jq
Requires:       xdg-utils
Requires:       systemd
Recommends:     xdotool
Recommends:     xset

Conflicts:      xiboplayer-electron

%description
Xibo PWA digital signage player for kiosk deployments on Fedora.
Launches a fullscreen browser pointing at a Xibo CMS PWA player URL,
with automatic restart and screen-blanking prevention.

%prep
# Files are placed directly during install

%build
# Nothing to build — noarch package of scripts and config

%install
rm -rf %{buildroot}

# Launch script
install -Dm755 %{_sourcedir}/xiboplayer/launch-kiosk.sh \
    %{buildroot}%{_libexecdir}/xiboplayer/launch-kiosk.sh

# Wrapper in PATH
install -Dm755 /dev/stdin %{buildroot}%{_bindir}/xiboplayer << 'WRAPPER'
#!/bin/bash
exec %{_libexecdir}/xiboplayer/launch-kiosk.sh "$@"
WRAPPER

# Config template (copied to ~/.config/xiboplayer/ on first run)
install -Dm644 %{_sourcedir}/xiboplayer/config.json \
    %{buildroot}%{_datadir}/xiboplayer/config.json.example

# Systemd user service
install -Dm644 %{_sourcedir}/xiboplayer/xiboplayer-kiosk.service \
    %{buildroot}%{_userunitdir}/xiboplayer-kiosk.service

# Desktop entry
install -Dm644 %{_sourcedir}/xiboplayer/xiboplayer.desktop \
    %{buildroot}%{_datadir}/applications/xiboplayer.desktop

%files
%{_bindir}/xiboplayer
%{_libexecdir}/xiboplayer/
%{_datadir}/xiboplayer/config.json.example
%{_userunitdir}/xiboplayer-kiosk.service
%{_datadir}/applications/xiboplayer.desktop

%post
echo ""
echo "  Xibo PWA Player installed."
echo ""
echo "  1. Run 'xiboplayer' once — creates ~/.config/xiboplayer/config.json"
echo "  2. Edit ~/.config/xiboplayer/config.json — set cmsUrl"
echo "  3. systemctl --user enable --now xiboplayer-kiosk.service"
echo ""

%preun
if [ "$1" -eq 0 ]; then
    echo "  Remember to: systemctl --user disable --now xiboplayer-kiosk.service"
fi

%changelog
* Mon Feb 16 2026 Pau Aliagas <linuxnow@gmail.com> - 1.0.0-1
- Renamed to xiboplayer-pwa, proper Fedora FHS paths
- Launch script in /usr/libexec/xiboplayer/
- Browser profiles in ~/.local/share/xiboplayer/
