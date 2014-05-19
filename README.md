# Spreaker Customized App - Resign app script

Thank you for purchasing your Customized App!
Before uploading your brand new app, you'll need to sign in with your distribution certificate.
The `prepare_ipa.sh` script is here, just for that!

If you need help or have any questions, visit http://help.spreaker.com.

Spreaker's Mobile Team
www.spreaker.com



## Requirements

### Installed software:
* XCode
* XCode Command line Tools
* Application Loader

### App in iTunes Connect:
* You need to set up an app inside the iTunes Connect portal.
In order to upload the .ipa with Application Loader, the app MUST be in the "Waiting for Upload" state.

### Information:
* An App Store Distribution Provisioning Profile (a .mobileprovision file)
* The certificate (with its private key) in your keychain, in order to use the distribution profile above
* The certificate identity name



## Execution

In order to run, the script needs 3 parameters in the command line:

* The .xcarchive file we provided you
* The developer identity name needed when using the provisioning profile
* The .mobileprovision file itself

In detail

* To find your developer identity, run the command
`security find-identity -p codesigning -v`
and look for the distribution certificate to use. It should look like this:
`"iPhone Distribution: MySelf (TeamID)"`
That's what you need to know.

* To get the `.mobileprovision`, simply visit the iTunes Connect Portal (https://developer.apple.com/account/ios/profile/profileList.action) and download the App Store Distribution Provisioning Profile related to this app.
If needed, create it from scratch. There are no restrictions regarding the app bundle ID to use. Feel free to create whatever you wish.
Copy the `.mobileprovision` file into the script folder.

* Finally, run the script like this:
`sh prepare_ipa.sh CustomApp-XXX.xcarchive "iPhone Distribution: MySelf (TeamID)" MyDistribution.mobileprovision`
The script will ask you for the password to access your keychain (in order to use the distribution certificate).
In a few seconds, the script completes its work and you'll find a new `.ipa` file in the folder.

* Use Application Loader to upload the `.ipa` file generated.


## License

Copyright (c) 2014 Spreaker, Inc. See the LICENSE file for license rights and limitations (MIT).
