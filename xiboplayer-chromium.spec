%global debug_package %{nil}

Name:           xiboplayer-chromium
Version:        0.3.0
Release:        1%{?dist}
Summary:        Self-contained Xibo digital signage player (Chromium kiosk)

License:        AGPL-3.0-or-later
URL:            https://github.com/xibo-players/%{name}
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
BuildRequires:  nodejs >= 18

Requires:       (chromium or google-chrome-stable)
Requires:       nodejs >= 18
Requires:       jq
Requires:       curl
Requires:       systemd
Recommends:     xdotool
Recommends:     xset

# Smooth upgrade from the old package name
Obsoletes:      xiboplayer-pwa < %{version}-%{release}
Provides:       xiboplayer-pwa = %{version}-%{release}

%description
Self-contained Xibo digital signage player for kiosk deployments.
Bundles the PWA player locally and serves it via a Node.js server,
then launches Chromium in kiosk mode. Only the CMS base URL is needed.

%prep
%setup -q -n %{name}-%{version}

%build
# Install Node.js server dependencies (fetches @xiboplayer/proxy + @xiboplayer/pwa)
cd server
npm install --production --no-optional 2>&1
cd ..

%install
# Server (Node.js + dependencies including bundled PWA)
install -Dm755 server/server.js %{buildroot}%{_libexecdir}/%{name}/server/server.js
cp server/package.json %{buildroot}%{_libexecdir}/%{name}/server/
cp -r server/node_modules %{buildroot}%{_libexecdir}/%{name}/server/

# Launch script
install -Dm755 launch-kiosk.sh \
    %{buildroot}%{_libexecdir}/%{name}/launch-kiosk.sh

# Wrapper in PATH
install -Dm755 /dev/stdin %{buildroot}%{_bindir}/%{name} << 'WRAPPER'
#!/bin/bash
exec %{_libexecdir}/xiboplayer-chromium/launch-kiosk.sh "$@"
WRAPPER

# Config template (copied to ~/.config/xiboplayer/ on first run)
install -Dm644 config.json \
    %{buildroot}%{_datadir}/%{name}/config.json.example

# Systemd user service
install -Dm644 %{name}.service \
    %{buildroot}%{_userunitdir}/%{name}.service

# Desktop entry
install -Dm644 %{name}.desktop \
    %{buildroot}%{_datadir}/applications/%{name}.desktop

# Icon
install -Dm644 xiboplayer.png \
    %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/xiboplayer.png

%files
%{_bindir}/%{name}
%{_libexecdir}/%{name}/
%{_datadir}/%{name}/
%{_userunitdir}/%{name}.service
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/256x256/apps/xiboplayer.png

%post
# Register alternatives (lower priority than Electron)
alternatives --install %{_bindir}/xiboplayer xiboplayer %{_bindir}/%{name} 50

touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

echo ""
echo "  Xibo Player (Chromium) installed."
echo ""
echo "  1. Run 'xiboplayer-chromium' once — creates ~/.config/xiboplayer/config.json"
echo "  2. Edit ~/.config/xiboplayer/config.json — set cmsUrl to your CMS address"
echo "  3. systemctl --user enable --now xiboplayer-chromium.service"
echo ""

%preun
if [ "$1" -eq 0 ]; then
    alternatives --remove xiboplayer %{_bindir}/%{name}
    echo "  Remember to: systemctl --user disable --now %{name}.service"
fi

%postun
if [ $1 -eq 0 ] ; then
    touch --no-create %{_datadir}/icons/hicolor &>/dev/null
    gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
fi

%changelog
* Thu Feb 20 2026 Pau Aliagas <linuxnow@gmail.com> - 0.3.0-1
- Bump SDK dependencies to 0.3.0 (SW refactored into @xiboplayer/sw)

* Wed Feb 19 2026 Pau Aliagas <linuxnow@gmail.com> - 0.2.1-1
- Use @xiboplayer/proxy for CORS proxy (shared with Electron)
- PWA bundled via npm dependency (no separate fetch step)
- Rename paths to xiboplayer-chromium (co-installable with Electron)
- Add alternatives support (xiboplayer → xiboplayer-chromium, priority 50)
- Add application icon

* Wed Feb 19 2026 Pau Aliagas <linuxnow@gmail.com> - 0.2.0-1
- Self-contained: bundle PWA player + local Node.js server
- No longer points Chromium at remote CMS PWA URL
- Requires nodejs for local server (CORS proxy + static files)
- Config only needs CMS base URL

* Tue Feb 18 2026 Pau Aliagas <linuxnow@gmail.com> - 0.1.0-1
- Initial RPM as xiboplayer-chromium
