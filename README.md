Ruby to script to build iOS apps on a Jenkins Build server and upload to hockeykit server

features:
- builds adhoc ipa or release archives with resigned adhoc ipa for testing release builds
- uploads files to hockeykit server for easy installs (https://github.com/TheRealKerni/HockeyKit)
- builds from a specific git branch
- sends success and failure emails with error note using gmail
- injects build number and app display into info.plist
- dumps build output to jenkins console