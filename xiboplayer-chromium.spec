%global debug_package %{nil}

Name:           xiboplayer-chromium
Version:        0.2.0
Release:        1%{?dist}
Summary:        Xibo PWA digital signage player (Chromium kiosk)

License:        AGPL-3.0-or-later
URL:            https://github.com/xibo-players/%{name}
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros

Requires:       (chromium or google-chrome-stable)
Requires:       jq
Requires:       xdg-utils
Requires:       systemd
Recommends:     xdotool
Recommends:     xset

# Smooth upgrade from the old package name
Obsoletes:      xiboplayer-pwa < %{version}-%{release}
Provides:       xiboplayer-pwa = %{version}-%{release}

Conflicts:      xiboplayer-electron

%description
Xibo PWA digital signage player for kiosk deployments on Fedora.
Launches a fullscreen Chromium browser pointing at a Xibo CMS PWA
player URL, with automatic restart and screen-blanking prevention.

%prep
# Files are placed directly during install

%build
# Nothing to build — noarch package of scripts and config

%install
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
echo "  Xibo Chromium Player installed."
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
* Tue Feb 18 2026 Pau Aliagas <linuxnow@gmail.com> - 0.2.0-1
- Rename package from xiboplayer-pwa to xiboplayer-chromium
- Add Obsoletes/Provides for smooth upgrades
- Conflict with xiboplayer-electron

* Mon Feb 16 2026 Pau Aliagas <linuxnow@gmail.com> - 0.1.0-1
- Initial RPM as xiboplayer-pwa
- Launch script in /usr/libexec/xiboplayer/
