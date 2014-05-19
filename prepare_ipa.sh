#!/bin/sh
# 
# Copyright (c) 2014 Spreaker Inc. (http://www.spreaker.com/)
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

if [ $# -lt 3 ]; then
        echo "Usage: $0 <.xcarchive file> <developer identity name> <.mobileprovision file>" >&2
        echo "See README file for more information."
        exit 1
fi


#
# Preparing local variables
#
echo "Preparing..."

WORKING_DIR=`pwd`
LOG_FILE="Log.log"

# Local commands
PLISTBUDDY=/usr/libexec/PlistBuddy
CODESIGN=/usr/bin/codesign
XCRUN=/usr/bin/xcrun

# User parameters
XCARCHIVE_FILE=$1
SIGNING_IDENTITY=$2
PROVISIONING_FILE=$3
echo "XCARCHIVE_FILE: $XCARCHIVE_FILE" >> $LOG_FILE 
echo "SIGNING_IDENTITY: $SIGNING_IDENTITY" >> $LOG_FILE 
echo "PROVISIONING_FILE: $PROVISIONING_FILE" >> $LOG_FILE 

# Generate ipa file name
OUTPUT_IPA_NAME=`echo $XCARCHIVE_FILE | awk '{split($0,a,"."); printf a[1] "-AppStoreReady.ipa"}'`
echo "OUTPUT_IPA_NAME: $OUTPUT_IPA_NAME" >> $LOG_FILE 

# Get app name
APP_NAME=`ls $XCARCHIVE_FILE/Products/Applications/ | cut -d . -f 1`
XCARCHIVE_INTERNAL_APP="$XCARCHIVE_FILE/Products/Applications/$APP_NAME.app"
echo "APP_NAME: $APP_NAME" >> $LOG_FILE 
echo "XCARCHIVE_INTERNAL_APP: $XCARCHIVE_INTERNAL_APP" >> $LOG_FILE 

# Get bundle identifier
FULL_APP_BUNDLE_ID=`egrep -a -A 2 application-identifier $PROVISIONING_FILE | grep string | sed -e 's/<string>//' -e 's/<\/string>//' -e 's/ //' -e 's/ //'`
APP_ID_PREFIX=`echo $FULL_APP_BUNDLE_ID | awk '{split($0,a,"."); print a[1]}'`
APP_BUNDLE_ID=`echo $FULL_APP_BUNDLE_ID | awk '{split($0,array,"."); delete array[1]; for(a in array) {printf array[a] "."}}' | sed -e 's/\.$//'`
echo "APP_ID_PREFIX: $APP_ID_PREFIX" >> $LOG_FILE 
echo "APP_BUNDLE_ID: $APP_BUNDLE_ID" >> $LOG_FILE 


#
# Copy .mobileprovision inside the app
#
cp "$PROVISIONING_FILE" "$XCARCHIVE_INTERNAL_APP/embedded.mobileprovision"


#
# Create a Entitlements.plist file and put it inside the app
#
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
   	<key>get-task-allow</key>
    <false/>
</dict>
</plist>
EOF

cp "Entitlements.plist" "$XCARCHIVE_INTERNAL_APP/Entitlements.plist"


#
# Edit Info.plist
#
echo "Updating Info.plist file..."
echo "NOTE: May ask for your keychain password"

# Change the top level Plist
${PLISTBUDDY} -c "Set:ApplicationProperties:CFBundleIdentifier $APP_BUNDLE_ID" "$XCARCHIVE_FILE/Info.plist"
${PLISTBUDDY} -c "Set:ApplicationProperties:SigningIdentity $SIGNING_IDENTITY" "$XCARCHIVE_FILE/Info.plist"

# Change the bundle ID in the embedded Info.plist 
${PLISTBUDDY} -c "Set:CFBundleIdentifier $APP_BUNDLE_ID" "$XCARCHIVE_INTERNAL_APP/Info.plist"

# Sign the changes
${CODESIGN} -f -s "$SIGNING_IDENTITY" --resource-rules="$XCARCHIVE_INTERNAL_APP/ResourceRules.plist" --entitlements Entitlements.plist "$XCARCHIVE_INTERNAL_APP" >> $LOG_FILE
if [ $? -ne 0 ]; then
	echo "ERROR: See '$LOG_FILE' for more details"
	exit 1
fi


#
# Build .ipa
#
echo "Building .ipa file..."

${XCRUN} -sdk iphoneos PackageApplication -v "$XCARCHIVE_INTERNAL_APP" -o "$WORKING_DIR/$OUTPUT_IPA_NAME" --sign "$SIGNING_IDENTITY" --embed "$PROVISIONING_PROFILE" >> $LOG_FILE
if [ $? -ne 0 ]; then
	echo "ERROR: See '$LOG_FILE' for more details"
	exit 1
fi


#
# Cleanup
#
rm "Entitlements.plist"
rm "$LOG_FILE"


#
# Done!
#
echo "Done!"
echo 
echo "Your .ipa file is available here:"
echo "$WORKING_DIR/$OUTPUT_IPA_NAME"
echo

exit 0
