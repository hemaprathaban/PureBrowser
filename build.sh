#!/bin/sh
set -e
clear
basedir=$(echo $PWD)

DEBEMAIL=dev@puri.sm
DEBFULLNAME="PureOS GNU/Linux developers"

# get source and cd into it.
echo "Removing previous build files..."
rm -rf purebrowser*
echo
echo "Obtaining sources..." 
apt-src install iceweasel

find . -maxdepth 1 -type d -exec rename "s/iceweasel/purebrowser/" {} \;

cd purebrowser*

# remove the Iceweasel branding icon and logo and replace it.
echo "Replacing logo and icon."
rm -f debian/branding/iceweasel_icon.svg debian/branding/iceweasel_logo.svg
cp "$basedir"/data/purebrowser* debian/branding/

# stragglers
for file in $(grep "iceweasel" . -rl)
do
	sed 's/iceweasel/purebrowser/g' -i "$file"
	echo "Editing $file"
done

for file in $(grep "Iceweasel" . -rl)
do
	sed 's/Iceweasel/PureBrowser/g' -i "$file"
	echo "Editing $file"
done

for file in $(find . -type d|grep iceweasel)
do
	rename 's/iceweasel/purebrowser/' -i "$file"
	echo "Renaming $file"
done

for file in $(find . -type f|grep iceweasel)
do
	rename 's/iceweasel/purebrowser/' -i "$file"
	echo "Renaming $file"
done

for file in $(grep "ICEWEASEL" . -rl)
do
	sed 's/ICEWEASEL/PUREBROWSER/g' -i "$file"
	echo "Editing $file"
done

# js settings
cat "$basedir"/data/settings.js >> browser/app/profile/purebrowser.js

# install purebrowser extensions
cp "$basedir"/data/extensions/* debian/ -r

echo "Adding Privacy Badger."
echo "debian/jid1-MnnxcxisBPnSXQ-eff@jetpack usr/lib/purebrowser/browser/extensions/" >> debian/browser.install.in

echo "Adding https-everywhere."
echo "debian/https-everywhere-eff@eff.org usr/lib/purebrowser/browser/extensions/" >> debian/browser.install.in

echo "Adding html5-video-everywhere."
echo "debian/html5-video-everywhere@lejenome.me usr/lib/purebrowser/browser/extensions/" >> debian/browser.install.in

# disable search field in extensions panel
echo "Disable search in extensions panel."
cat << EOF >> toolkit/mozapps/extensions/content/extensions.css
header-search {
  display:none;
}
EOF

# Postinst script to manage profile migration and system links
echo '

if [ "$1" = "configure" ] || [ "$1" = "abort-upgrade" ] ; then

[ -f /usr/bin/firefox ] || ln -s /usr/bin/purebrowser /usr/bin/firefox

for HOMEDIR in $(grep :/home/ /etc/passwd |grep -v usbmux |grep -v syslog|cut -d : -f 6)
do
    [ -d $HOMEDIR/.mozilla/purebrowser ] && continue || true
    [ -d $HOMEDIR/.mozilla/firefox ] || continue
    echo Linking $HOMEDIR/.mozilla/firefox into $HOMEDIR/.mozilla/purebrowser
    ln -s $HOMEDIR/.mozilla/firefox $HOMEDIR/.mozilla/purebrowser
done 
fi
exit 0 ' > debian/browser.postinst.in

#cat << EOF >> browser/app/Makefile.in
#libs::
#	cp -a \$(topsrcdir)/extensions/* \$(FINAL_TARGET)/extensions/
#	mkdir -p \$(DIST)/purebrowser/browser/extensions/ 
#	cp -a \$(topsrcdir)/extensions/* \$(DIST)/purebrowser/browser/extensions/
#EOF

#cat << EOF >> mobile/android/app/Makefile.in
#libs::
#	mkdir -p \$(DIST)/bin/distribution
#	cp -a \$(topsrcdir)/extensions/ \$(DIST)/bin/distribution/extensions
#EOF

#for EXTENSION in $(ls $basedir/data/extensions/); do
#	sed "/Browser Chrome Files/s%$%\n@BINPATH@/browser/extensions/$EXTENSION/*%" -i browser/installer/package-manifest.in mobile/android/installer/package-manifest.in
#done

# disconnect.me search engine as home page
sed -e "/startup.homepage_override/d" \
    -e "/startup.homepage_welcome/d" \
    -i debian/branding/firefox-branding.js

cat << EOF >> debian/branding/firefox-branding.js
pref("startup.homepage_override_url","https://duckduckgo.com");
pref("startup.homepage_welcome_url","https://duckduckgo.com");
EOF
export DEBEMAIL DEBFULLNAME && dch -m "Duckduckgo search page as home."

# preferences hardening
cat << EOF >>debian/vendor.js.in
// disable Location-Aware Browsing
// http://www.mozilla.org/en-US/firefox/geolocation/
pref("geo.enabled",             false);
EOF
dch -m "Disable location-aware browsing."

cat << EOF >>debian/vendor.js.in
pref("media.peerconnection.enabled",            false);
EOF
dch -m "Disable media peer connections for internal IP leak."

cat << EOF >>debian/vendor.js.in
// https://developer.mozilla.org/en-US/docs/Web/API/BatteryManager
pref("dom.battery.enabled",             false);
EOF
dch -m "Disable battery monitor for internal IP leak."

cat << EOF >>debian/vendor.js.in
// https://wiki.mozilla.org/WebAPI/Security/WebTelephony
pref("dom.telephony.enabled",           false);
EOF
dch -m "Disable web telephony for internal IP leak."

# search plugins
rm -f browser/locales/en-US/searchplugins/*.xml
cp "$basedir"/data/searchplugins/* browser/locales/en-US/searchplugins -a
cat << EOF > browser/locales/en-US/searchplugins/list.txt
duckduckgo
disconnectme
ixquick
startpage
creativecommons
wikipedia
EOF

# patches
for patchfile in $(ls "$basedir"/data/patches/)
do
	patch --verbose -p1 < "$basedir"/data/patches/"$patchfile"
done

cat << EOF >> browser/confvars.sh
# PureBrowser settings
MOZ_APP_VENDOR=PURISM
MOZ_APP_VERSION=38.2.1esr+pureos1
MOZ_APP_PROFILE=mozilla/purebrowser
MOZ_PAY=0
MOZ_SERVICES_HEALTHREPORT=0
MOZ_SERVICES_HEALTHREPORTER=0
MOZ_SERVICES_FXACCOUNTS=0
MOZ_SERVICES_METRICS=0
MOZ_DATA_REPORTING=0
MOZ_SERVICES_SYNC=0
MOZ_DEVICES=0
MOZ_ANDROID_GOOGLE_PLAY_SERVICES=0
EOF

sed 's/mozilla-esr/purism-esr/' -i browser/confvars.sh

# change the name of the app
sed -e 's/iceweasel/purebrowser/g' -i debian/control.in debian/changelog
sed -e "s_^Maintainer.*_Maintainer: PureOS GNU/Linux developers <dev@puri.sm>_g" \
    -i debian/control.in
sed -e "s/^Conflicts:/Conflicts: iceweasel,/g" -i debian/control.in
sed -e "s/Provides:/Provides: iceweasel,/g" -i debian/control.in
sed -e "/Breaks/ a\
        Replaces: iceweasel" -i debian/control.in
sed -e "s_^Maintainer.*_Maintainer: $DEBFULLNAME <$DEBEMAIL>_g" -i debian/control.in

echo "Refreshing control file."
debian/rules debian/control
touch -d "yesterday" debian/control
debian/rules debian/control
touch configure js/src/configure
# Fix CVE-2009-4029
sed 's/777/755/;' -i toolkit/crashreporter/google-breakpad/Makefile.in
# Fix CVE-2012-3386
/bin/sed 's/chmod a+w/chmod u+w/' -i ./js/src/ctypes/libffi/Makefile.in ./toolkit/crashreporter/google-breakpad/Makefile.in ./toolkit/crashreporter/google-breakpad/src/third_party/glog/Makefile.in || true

./mach generate-addon-sdk-moz-build

# Fix bug when replacing iceweasel
mv debian/browser.preinst.in debian/browser.postinst.in

export DEBEMAIL DEBFULLNAME
#vendor.js file doesnt exist
#dch "Harden vendor.js preferences."
dch -p -l "-1" "Converted into PureBrowser."

echo "Building PureBrowser..."
apt-src import purebrowser --here
cd $basedir
apt-src build purebrowser

# the build is done with apt-src because it takes care of generating a
# patch to contain all of the local changes made. this doesn't always
# work, but for the purpose of this package it works very nicely.
