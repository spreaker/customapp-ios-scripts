#!/bin/sh
# 
# Copyright (c) 2015 Spreaker Inc. (http://www.spreaker.com/)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#


#
# Spreaker Custom App - Resign app script
# 

# Prepare common stuff
WORKING_DIR=`pwd`
LOG_FILE="Log.log"

AWK="$(which awk)"
SED="$(which sed)"
PLISTBUDDY=/usr/libexec/PlistBuddy
CODESIGN="$(which codesign)"
XCODEBUILD="$(which xcodebuild)"


#
# Select xcarchive file
#
XCARCHIVE_FILE=`ls $WORKING_DIR | grep .xcarchive`
if [ -z "$XCARCHIVE_FILE" ]; then
 	echo "ERROR: Missing xcarchive file from current directory."
	exit 1
fi
echo "Found archive: $XCARCHIVE_FILE"


#
# Select mobileprovision file
#
PROVISIONING_FILE=`ls $WORKING_DIR | grep .mobileprovision`
if [ -z "$PROVISIONING_FILE" ]; then
 	echo "ERROR: Missing mobileprovision file from current directory."
	exit 1
fi
echo "Found provisioning file: $PROVISIONING_FILE"


#
# Select signing identity available
#
FETCHED_IDENTITIES=`security find-identity -p codesigning -v`
SIGNING_IDENTITIES=""
while read -r line; do
	IDENTITY=`echo $line | ${AWK} '/iPhone/ { print $0 }'`
	if [ -n "$IDENTITY" ]; then
    	SIGNING_IDENTITIES="$SIGNING_IDENTITIES$IDENTITY\n"
	fi
done <<< "$FETCHED_IDENTITIES"

echo "Select propert identity for signing the app:"
echo "$SIGNING_IDENTITIES"
read -p "Type the number of the signing identity to use: " IDENTITY_INDEX

SIGNING_IDENTITY=`echo "$SIGNING_IDENTITIES" | ${SED} -n ${IDENTITY_INDEX}p | ${SED} 's/[^"]*"\([^"]*\)".*/\1/'`
if [ -z "$SIGNING_IDENTITY" ]; then
	echo "ERROR: Invalid signing identity."
	exit 1
fi
echo "Using signing identity: \"$SIGNING_IDENTITY\""


#
# Re-signing
#
echo "Preparing..."

# Log some information
echo "XCARCHIVE_FILE: $XCARCHIVE_FILE" >> $LOG_FILE 
echo "SIGNING_IDENTITY: $SIGNING_IDENTITY" >> $LOG_FILE 
echo "PROVISIONING_FILE: $PROVISIONING_FILE" >> $LOG_FILE 

# Generate ipa file name
OUTPUT_IPA_NAME=`echo $XCARCHIVE_FILE | ${AWK} '{split($0,a,"."); printf a[1] "-AppStoreReady.ipa"}'`
echo "OUTPUT_IPA_NAME: $OUTPUT_IPA_NAME" >> $LOG_FILE 
OUTPUT_IPA_PATH=`echo $WORKING_DIR/ReadyForAppstore`
echo "OUTPUT_IPA_PATH: $OUTPUT_IPA_PATH" >> $LOG_FILE 

# Get app name
APP_NAME=`ls $XCARCHIVE_FILE/Products/Applications/ | cut -d . -f 1`
XCARCHIVE_INTERNAL_APP="$XCARCHIVE_FILE/Products/Applications/$APP_NAME.app"
echo "APP_NAME: $APP_NAME" >> $LOG_FILE 
echo "XCARCHIVE_INTERNAL_APP: $XCARCHIVE_INTERNAL_APP" >> $LOG_FILE 

# Get bundle identifier
FULL_APP_BUNDLE_ID=`egrep -a -A 2 application-identifier $PROVISIONING_FILE | grep string | ${SED} -e 's/<string>//' -e 's/<\/string>//' -e 's/ //' -e 's/ //'`
APP_ID_PREFIX=`echo $FULL_APP_BUNDLE_ID | ${AWK} '{ split($0,a,"."); print a[1] }'`
APP_BUNDLE_ID=`echo $FULL_APP_BUNDLE_ID | ${AWK} '{ split($0,array,"."); delete array[1]; for(a in array) {printf array[a] "."} }' | ${SED} -e 's/\.$//'`
echo "APP_ID_PREFIX: $APP_ID_PREFIX" >> $LOG_FILE 
echo "APP_BUNDLE_ID: $APP_BUNDLE_ID" >> $LOG_FILE 


#
# Install provisioning profile
#
echo "Preparing provisioning profile..."

# First, inside the machine itself
PROVISIONING_CONTENT=$(security cms -D -i $PROVISIONING_FILE)
UUID=$(${PLISTBUDDY} -c "Print :UUID" /dev/stdin <<< $PROVISIONING_CONTENT)
cp "$PROVISIONING_FILE" "$HOME/Library/MobileDevice/Provisioning Profiles/${UUID}.mobileprovision"

# Then inside the app
cp "$PROVISIONING_FILE" "$XCARCHIVE_INTERNAL_APP/embedded.mobileprovision"


#
# Preparing xcarchive
#
echo "Updating xcarchive..."

# Create a Entitlements.plist file and put it inside the app
cat << EOF > Entitlements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>application-identifier</key>
	<string>$APP_ID_PREFIX.$APP_BUNDLE_ID</string>
	<key>keychain-access-groups</key>
	<array>
		<string>$APP_ID_PREFIX.$APP_BUNDLE_ID</string>
	</array>
	<key>com.apple.developer.team-identifier</key>
	<string>$APP_ID_PREFIX</string>
   	<key>get-task-allow</key>
    <false/>
</dict>
</plist>
EOF

cp "Entitlements.plist" "$XCARCHIVE_INTERNAL_APP/Entitlements.plist"

# NOTE: File added with iOS9
if [ -f "$XCARCHIVE_INTERNAL_APP/archived-expanded-entitlements.xcent" ]; then
	${PLISTBUDDY} -c "Set :application-identifier $APP_ID_PREFIX.$APP_BUNDLE_ID" "$XCARCHIVE_INTERNAL_APP/archived-expanded-entitlements.xcent"
	${PLISTBUDDY} -c "Set :keychain-access-groups:0 $APP_ID_PREFIX.$APP_BUNDLE_ID" "$XCARCHIVE_INTERNAL_APP/archived-expanded-entitlements.xcent"
fi

#
# Edit Info.plist
#
echo "Updating Info.plist file..."
echo "ATTENTION: May ask for your keychain access. Please allow it"

# Change the top level Plist
${PLISTBUDDY} -c "Set :ApplicationProperties:CFBundleIdentifier $APP_BUNDLE_ID" "$XCARCHIVE_FILE/Info.plist"
${PLISTBUDDY} -c "Set :ApplicationProperties:SigningIdentity $SIGNING_IDENTITY" "$XCARCHIVE_FILE/Info.plist"

# Change the bundle ID in the embedded Info.plist 
${PLISTBUDDY} -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$XCARCHIVE_INTERNAL_APP/Info.plist"

echo "Re-signing..."

# Sign the changes 
${CODESIGN} --force --sign "$SIGNING_IDENTITY" --entitlements "Entitlements.plist" "$XCARCHIVE_INTERNAL_APP" >> $LOG_FILE 
if [ $? -ne 0 ]; then
    echo "ERROR: See '$LOG_FILE' for more details"     
    exit 1 
fi


#
# Export .ipa
#
echo "Exporting .ipa file..."

# Creates an export options plist file
cat << EOF > exportOptions.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>teamID</key>
        <string>$APP_ID_PREFIX</string>
        <key>method</key>
        <string>app-store</string>
        <key>uploadSymbols</key>
        <true/>
</dict>
</plist>
EOF

# Run new exportArchive command
${XCODEBUILD} -exportArchive -exportOptionsPlist exportOptions.plist -archivePath "$XCARCHIVE_FILE" -exportPath "$OUTPUT_IPA_PATH" >> $LOG_FILE
if [ $? -ne 0 ]; then
	echo "ERROR: See '$LOG_FILE' for more details"
	exit 1
fi


#
# Cleanup
#
rm "Entitlements.plist"
rm "exportOptions.plist"
rm "$LOG_FILE"


#
# Done!
#
echo "Done!"
echo 
echo "Your .ipa file is available inside here:"
echo "$OUTPUT_IPA_PATH"
echo


#
# Opens Application loader, if possible
#

APPLICATION_LOADER=""
if [ -d "/Applications/Application Loader.app" ]; then
	APPLICATION_LOADER="/Applications/Application Loader.app"
elif [ -d "/Applications/Xcode.app" ]; then
	APPLICATION_LOADER="/Applications/Xcode.app/Contents/Applications/Application Loader.app"
fi

if [ -n "$APPLICATION_LOADER" ]; then
	echo "Launching Application Loader. To upload the ipa, click on \"Deliver Your App\" and select the generated .ipa file. Then follow the on-screen steps."
	
	open -a "$APPLICATION_LOADER" "$OUTPUT_IPA_PATH/CustomApp Prod.ipa"
fi

exit 0
