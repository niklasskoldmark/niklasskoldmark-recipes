#!/bin/sh

#if [ "$3" == "/" ]; then
#    TARGETVOL=""
#else
#    TARGETVOL="$3"
#fi

TARGETVOL="{{target_volume}}"

echo "All 3 = $3" >> "$TARGETVOL"/log.txt
echo "All target_volume = {{target_volume}}" >> "$TARGETVOL"/log.txt
echo "All TARGETVOL = $TARGETVOL" >> "$TARGETVOL"/log.txt

DefaultsCMD="$TARGETVOL/usr/bin/defaults"
echo "All DefaultsCMD = $DefaultsCMD" >> "$TARGETVOL"/log.txt
PLBUDDY="$TARGETVOL/usr/libexec/PlistBuddy"
echo "All PLBUDDY = $PLBUDDY" >> "$TARGETVOL"/log.txt


## SetEuropeanTimeServer
file="$TARGETVOL/private/etc/ntp.conf"
echo "SetEuropeanTimeServer file = $file" >> "$TARGETVOL"/log.txt
touch "$file"
echo "server time.euro.apple.com" > "$file"
# -rw-r--r--@
chmod 644 "$file"
chown root:wheel "$file"


# SetStockholmTimeZone
file="$TARGETVOL/private/etc/localtime"
echo "SetStockholmTimeZone file = $file" >> "$TARGETVOL"/log.txt
rm "$file"
ln -s "/usr/share/zoneinfo/Europe/Stockholm" "$file"
#lrwxr-xr-x
chmod 755 "$file"
chown root:wheel "$file"

# SetSwedishRegion
file="$TARGETVOL/Library/Preferences/.GlobalPreferences.plist"
echo "SetSwedishRegion file = $file" >> "$TARGETVOL"/log.txt
touch "$file"
"$DefaultsCMD" write "$file" AppleLocale sv_SE
"$DefaultsCMD" write "$file" Country SE
"$DefaultsCMD" read "$file" >> "$TARGETVOL"/log.txt

# SetSwedishLanguage
file="$TARGETVOL/Library/Preferences/.GlobalPreferences.plist"
echo "SetSwedishLanguage file = $file" >> "$TARGETVOL"/log.txt
touch "$file" 
"$DefaultsCMD" write "$file" AppleLanguages '(sv)'
echo "SetSwedishLanguage file = $file" >> "$TARGETVOL"/log.txt
"$DefaultsCMD" read "$file" >> "$TARGETVOL"/log.txt

# SetSwedishKeyboard
KeyboardLayoutName="Swedish - Pro"
KeyboardLayout="Swedish-Pro"
KeyboardLayoutID="7"

update_kdb_layout() {
  #logger "SetSwedishKeyboard Updating file '${1}'"
  echo "SetSwedishKeyboard Updating file '${1}'" >> "$TARGETVOL"/log.txt
  ${PLBUDDY} -c "Delete :AppleCurrentKeyboardLayoutInputSourceID" "${1}" &>/dev/null
  if [ ${?} -eq 0 ] || [ -n "${4}" ]
  then
    #${PLBUDDY} -c "Add :AppleCurrentKeyboardLayoutInputSourceID string com.apple.keylayout.${2}" "${1}"
    ${PLBUDDY} -c "Add :AppleCurrentKeyboardLayoutInputSourceID string com.apple.keylayout.$KeyboardLayout" "${1}"
  fi

  for SOURCE in AppleDefaultAsciiInputSource AppleCurrentAsciiInputSource AppleCurrentInputSource AppleEnabledInputSources AppleSelectedInputSources
  do
    ${PLBUDDY} -c "Delete :${SOURCE}" "${1}" &>/dev/null
    if [ ${?} -eq 0 ] || [ -n "${4}" ]
    then
      ${PLBUDDY} -c "Add :${SOURCE} array" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0 dict" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0:InputSourceKind string 'Keyboard Layout'" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0:KeyboardLayout\ ID integer ${3}" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0:KeyboardLayout\ Name string '${2}'" "${1}"
    fi
  done
}

update_kdb_layout "$TARGETVOL/Library/Preferences/com.apple.HIToolbox.plist" "$KeyboardLayoutName" "$KeyboardLayoutID" --force

#if [ -d "$TARGETVOL"/var/root/Library/Preferences ]
#then
  cd "$TARGETVOL"/var/root/Library/Preferences
  HITOOLBOX_FILES="$(find . -name "com.apple.HIToolbox.*plist")"
  for HITOOLBOX_FILE in ${HITOOLBOX_FILES}
  do
    update_kdb_layout "${HITOOLBOX_FILE}" "$KeyboardLayoutName" "$KeyboardLayoutID" --force
  done
#fi

for HOME in "${TARGETVOL}"/Users/*
do
  if [ -d "${HOME}"/Library/Preferences ]
  then
    cd "${HOME}"/Library/Preferences
    HITOOLBOX_FILES=`find . -name "com.apple.HIToolbox.*plist"`
    for HITOOLBOX_FILE in ${HITOOLBOX_FILES}
    do
      update_kdb_layout "${HITOOLBOX_FILE}" "$KeyboardLayoutName" "$KeyboardLayoutID"
    done
  fi
done

for USER_TEMPLATE in "$TARGETVOL/System/Library/User Template"/*
  do
    if [ -d "${USER_TEMPLATE}"/Library/Preferences ]
    then
      cd "${USER_TEMPLATE}"/Library/Preferences
      HITOOLBOX_FILES=`find . -name "com.apple.HIToolbox.*plist"`
      for HITOOLBOX_FILE in ${HITOOLBOX_FILES}
      do
        update_kdb_layout "${HITOOLBOX_FILE}" "$KeyboardLayoutName" "$KeyboardLayoutID"
      done
    fi
  done


# EnableLocationServices
uuid="$("$TARGETVOL/usr/sbin/system_profiler" SPHardwareDataType | grep "Hardware UUID" | cut -c22-57)"
echo "EnableLocationServices uuid = $uuid" >> "$TARGETVOL"/log.txt
"$DefaultsCMD" write "$TARGETVOL/var/db/locationd/Library/Preferences/ByHost/com.apple.locationd.$uuid" LocationServicesEnabled -int 1
"$DefaultsCMD" read "$TARGETVOL/var/db/locationd/Library/Preferences/ByHost/com.apple.locationd.$uuid" >> "$TARGETVOL"/log.txt
chown -R _locationd:_locationd "$TARGETVOL/var/db/locationd"

# DisableIcloudOnLogin

# Determine OS version
#osvers=$(sw_vers -productVersion | awk -F. '{print $2}')
#sw_vers=$(sw_vers -productVersion)

# Determine OS build number
#sw_build=$(sw_vers -buildVersion)

# Determine OS version
ProductVersion="$("$DefaultsCMD" read "$TARGETVOL/System/Library/CoreServices/SystemVersion.plist" ProductVersion)"
echo "DisableErrorReporting : ProductVersion=$ProductVersion" >> "$TARGETVOL"/log.txt

# Determine Main OS version
MainProductVersion=$(echo "$ProductVersion" | awk -F. '{print $2}')
echo "DisableErrorReporting : MainProductVersion=$MainProductVersion" >> "$TARGETVOL"/log.txt

# Determine OS build number
ProductBuildVersion="$("$DefaultsCMD" read "$TARGETVOL/System/Library/CoreServices/SystemVersion.plist" ProductBuildVersion)"
echo "DisableErrorReporting : ProductBuildVersion=$ProductBuildVersion" >> "$TARGETVOL"/log.txt

# Checks first to see if the Mac is running 10.7.0 or higher. 
# If so, the script checks the system default user template
# for the presence of the Library/Preferences directory. Once
# found, the iCloud and Diagnostic pop-up settings are set 
# to be disabled.

if [[ ${MainProductVersion} -ge 7 ]]; then

 for USER_TEMPLATE in "$TARGETVOL/System/Library/User Template"/*
  do
    "$DefaultsCMD" write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
    "$DefaultsCMD" write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
    "$DefaultsCMD" write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${ProductVersion}"
    "$DefaultsCMD" write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenBuddyBuildVersion "${ProductBuildVersion}"
    echo "DisableErrorReporting : USER_TEMPLATE=$USER_TEMPLATE" >> "$TARGETVOL"/log.txt
    "$DefaultsCMD" read "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant >> "$TARGETVOL"/log.txt      
  done
  
 # Checks first to see if the Mac is running 10.7.0 or higher.
 # If so, the script checks the existing user folders in /Users
 # for the presence of the Library/Preferences directory.
 #
 # If the directory is not found, it is created and then the
 # iCloud and Diagnostic pop-up settings are set to be disabled.

 for USER_HOME in "$TARGETVOL"/Users/*
  do
    USER_UID=`basename "${USER_HOME}"`
    if [ ! "${USER_UID}" = "Shared" ]; then
      if [ ! -d "${USER_HOME}"/Library/Preferences ]; then
        /bin/mkdir -p "${USER_HOME}"/Library/Preferences
        /usr/sbin/chown "${USER_UID}" "${USER_HOME}"/Library
        /usr/sbin/chown "${USER_UID}" "${USER_HOME}"/Library/Preferences
      fi
      if [ -d "${USER_HOME}"/Library/Preferences ]; then
        "$DefaultsCMD" write "${USER_HOME}"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
        "$DefaultsCMD" write "${USER_HOME}"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
        "$DefaultsCMD" write "${USER_HOME}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${ProductVersion}"
        "$DefaultsCMD" write "${USER_HOME}"/Library/Preferences/com.apple.SetupAssistant LastSeenBuddyBuildVersion "${ProductBuildVersion}"
        echo "DisableErrorReporting : USER_HOME=$USER_HOME" >> "$TARGETVOL"/log.txt
        "$DefaultsCMD" read "${USER_HOME}"/Library/Preferences/com.apple.SetupAssistant >> "$TARGETVOL"/log.txt
        /usr/sbin/chown "${USER_UID}" "${USER_HOME}"/Library/Preferences/com.apple.SetupAssistant.plist
      fi
    fi
  done
fi

touch "$TARGETVOL/private/var/db/.AppleSetupDone"

exit 0

