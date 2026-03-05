%global debug_package %{nil}

Name:           xiboplayer-chromium
Version:        0.6.3
Release:        1%{?dist}
Summary:        Self-contained Xibo digital signage player (Chromium kiosk)

License:        AGPL-3.0-or-later
URL:            https://xiboplayer.org
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

# Minimal config (copied to ~/.config/xiboplayer/ on first run)
install -Dm644 config.json \
    %{buildroot}%{_datadir}/%{name}/config.json

# Full config reference with all options documented
install -Dm644 config.json.example \
    %{buildroot}%{_docdir}/%{name}/config.json.example

# Documentation
install -Dm644 CONFIG.md \
    %{buildroot}%{_docdir}/%{name}/CONFIG.md
install -Dm644 README.md \
    %{buildroot}%{_docdir}/%{name}/README.md

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
%{_docdir}/%{name}/
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
* Thu Mar 05 2026 Pau Aliagas <linuxnow@gmail.com> - 0.6.3-1
- Canvas regions, protocol auto-detect, persistent durations, XIC handlers, download resume, vitest 4 upgrade

* Wed Mar 04 2026 Pau Aliagas <linuxnow@gmail.com> - 0.6.2-1
- fix: expire current layout when schedule changes, fix: multi-widget playlist cycling, fix: layout background fallback for storedAs filenames, refactor: single source of truth for layout duration calculation

* Tue Mar 03 2026 Pau Aliagas <linuxnow@gmail.com> - 0.6.1-1
- feat: switch default clientType from chromeOS to linux, fix: keyboard shortcuts on Wayland and quit for Chromium kiosk, fix: replace globalShortcut with Menu accelerators for Wayland (Electron), refactor: use shared packaging library for build scripts, fix: remove per-build repo update trigger race conditions

* Mon Mar 02 2026 Pau Aliagas <linuxnow@gmail.com> - 0.6.0-1
- REST v2 transport with auto-detection, chunked download resume, shared config extraction (extractPwaConfig), cert warning overlay fix, download overlay fix

* Sun Mar 01 2026 Pau Aliagas <linuxnow@gmail.com> - 0.5.20-1
- Fix memory leaks: PDF single-canvas rendering with page.cleanup(), event listener cleanup on widget hide, HLS instance destroy, blob URL tracking

* Sat Feb 28 2026 Pau Aliagas <linuxnow@gmail.com> - 0.5.19-1
- PDF multi-page cycling, SSL cert relaxation (relaxSslCerts), configurable log levels, config passthrough fixes

* Sat Feb 28 2026 Pau Aliagas <linuxnow@gmail.com> - 0.5.18-1
- Fix proxy crash, improve kill patterns, forward proxy logs to DevTools

* Sat Feb 28 2026 Pau Aliagas <linuxnow@gmail.com> - 0.5.17-1
- Decouple Chromium from SDK monorepo, fix cache clearing

* Fri Feb 28 2026 Pau Aliagas <linuxnow@gmail.com> - 0.5.16-4
- Fall back to Google Chrome when Chromium binary is not found
- Add --server-dir, --pwa-path and --no-kiosk CLI options for development

* Fri Feb 27 2026 Pau Aliagas <linuxnow@gmail.com> - 0.5.16-3
- Install default config.json (not config.json.example) for first-run copy
- Install full config reference and docs (CONFIG.md, README.md) to /usr/share/doc
- Add webcam/microphone capture policies (VideoCaptureAllowed, AudioCaptureAllowed)
- Add optional Google Geolocation API key support (googleGeoApiKey)
- Add config.json controls for keyboard shortcuts and mouse hover
- Add transport config option (auto/xmds) for unpatched Xibo CMS
