#!/bin/sh
# MakeFirstLoggedInUserAdmin

if [ "$3" == "/" ]; then
    TARGETVOL=""
else
    TARGETVOL="$3"
fi
TARGETVOL="{{target_volume}}"
DefaultsCMD="$TARGETVOL/usr/bin/defaults"

#logger "MakeFirstLoggedInUserAdmin : Start"

# Path to NewLoginHook
LoginHook="$TARGETVOL/private/etc/hooks/login/MakeFirstLoggedInUserAdmin.sh"

mkdir -p "$(dirname "$LoginHook")"

cat > "$LoginHook" << 'EOF'
#!/bin/bash
##	Promote the first (and ONLY first) Active Directory user that logs in to local admin status
# Get loggedInUsername
loggedInUsername="$1" && \
    logger "MakeFirstLoggedInUserAdmin : loggedInUsername=$loggedInUsername"

# Get loggedInUID
loggedInUID=$(/usr/bin/id -P $loggedInUsername | awk -F: '{ print $3 }') && \
    logger "MakeFirstLoggedInUserAdmin : loggedInUID=$loggedInUID"

# Check if user is already admin
isAdmin="$( /usr/sbin/dseditgroup -o checkmember -m $loggedInUsername admin 1&gt; /dev/null; echo $? )" && \
    logger "MakeFirstLoggedInUserAdmin : Check if $loggedInUsername is already admin"

# Check if user is an AD-account
logger "MakeFirstLoggedInUserAdmin : Check if $loggedInUID is an AD-account"
if [[ $loggedInUID > 1000 ]] ; then
     Check if user is an adminaccount
    if [[ "$isAdmin" -gt 0 ]]; then
        # Make user admin
        logger "MakeFirstLoggedInUserAdmin : Make $loggedInUsername admin"
        /usr/sbin/dseditgroup -o edit -a $loggedInUsername -t user admin
        # Test for success
        if [[ "$?" == 0 ]]; then
            # Operation successful
            logger "MakeFirstLoggedInUserAdmin : Promotion successful"
            # Set loginmessage
            defaults write "$RootDrive/Library/Preferences/com.apple.loginwindow" LoginwindowText "Denna dator \\U00e4gs av Medborgarskolan.\\n\\nOm du hittat datorn v\\U00e4nligen ring : 010 157 64 00." && \
                logger "MakeFirstLoggedInUserAdmin : Set loginmessage to : Denna dator \\U00e4gs av Medborgarskolan.\\n\\nOm du hittat datorn v\\U00e4nligen ring : 010 157 64 00."
            # Set Remote Desktop description to $loggedInUsername
            defaults write /Library/Preferences/com.apple.RemoteDesktop.plist Text1 "$loggedInUsername" && \
                logger "MakeFirstLoggedInUserAdmin : Set Remote Desktop description to $loggedInUsername"
            # Set ManagedInstalls.plist ClientIdentifier to $loggedInUsername
            defaults write /Library/Preferences/ManagedInstalls.plist ClientIdentifier "$loggedInUsername" && \
                logger "MakeFirstLoggedInUserAdmin : Set ManagedInstalls.plist ClientIdentifier to $loggedInUsername"
            # SelfDestruct
            rm -- "$0" && \
                logger "MakeFirstLoggedInUserAdmin : LoginHook SelfDestruct"
            exit 0
        else
            # Operation not successful
            logger "MakeFirstLoggedInUserAdmin : LoginHook Operation not successful"
            exit 1
        fi
    else
        # Is already admin
        logger "MakeFirstLoggedInUserAdmin : $loggedInUsername $loggedInUID is already an admin. Exiting..."
        exit 0
    fi
else
    # Is not an AD-account
    logger "MakeFirstLoggedInUserAdmin : $loggedInUsername $loggedInUID is not an Active Directory account. Exiting..."
    exit 0
fi

# Set loginmessage Set loginmessage to : Denna dator \\U00e4gs av Medborgarskolan.\\n\\nOm du hittat datorn v\\U00e4nligen ring : 010 157 64 00
"$DefaultsCMD" write "$TARGETVOL/Library/Preferences/com.apple.loginwindow" LoginwindowText "Denna dator \\U00e4gs av Medborgarskolan.\\n\\nOm du hittat datorn v\\U00e4nligen ring : 010 157 64 00" && \
    logger "logger MakeFirstLoggedInUserAdmin : Set loginmessage to : Denna dator \\U00e4gs av Medborgarskolan.\\n\\nOm du hittat datorn v\\U00e4nligen ring : 010 157 64 00"

EOF
 
chmod 700 "$LoginHook" && \
    logger "MakeFirstLoggedInUserAdmin : Script permissions set"

"$DefaultsCMD" write "$TARGETVOL/var/root/Library/Preferences/com.apple.loginwindow" LoginHook "$LoginHook" && \
    logger "MakeFirstLoggedInUserAdmin : Loginhook activated"

exit 0
