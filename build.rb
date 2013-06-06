#!/usr/bin/ruby

# written by chris elliott on 2/25/2013

# dependancies:
# sudo gem install tlsmail
# sudo gem install tmail
# sudo gem install plist
# sudo gem install json


# requirements
require 'rubygems'
require 'plist'
require File.join(File.dirname(__FILE__),  'gmail_handler.rb')


# build script varibles  
    emailHandler=GMailHandler.new
    buildStartedTime=Time.now

  # hardcoded varibles  
    prefabPath = File.join(File.dirname(__FILE__), "assets/manifest_prefab.plist")
    codeSigningIdentity="iPhone Distribution: Example Company"
    archivesPath="/Users/Shared/Jenkins/archives/"
    installDiskRootPath="/Library/Server/Web/Data/Sites/Default/install"
    failureEmail="failure@example.com"
    
  # pulled from jenkins
    home = File.expand_path("..",Dir.pwd)
    lastSuccessfulBuild="#{home}/lastSuccessfulBuild"
    workspace=ENV['WORKSPACE']
    buildBranch="#{ENV['buildBranch']}"
    projectName="#{ENV['JOB_NAME']}"
    if projectName.include? '-'
      projName=projectName.slice(0..(projectName.index('-')))[0..-2]  
    else
      projName = projectName
    end     
    hockeykitVersion=buildBranch.sub( "origin/", "" )
    hockeykitVersionCap=hockeykitVersion.to_s
    hockeykitVersionCap[0] = hockeykitVersionCap.first.capitalize[0]
    xcodeDir="#{projName}"
    scheme="#{projName}"
    target="#{projName}"
    jobName="#{projName}"
    xcworkspace="#{projName}"
    configuration=ENV['configuration']
    buildNumber=ENV['BUILD_NUMBER']
    successEmail="#{ENV['successEmail']}".delete(' ')
    jobUrl=ENV['JOB_URL']
    lastSuccessBuildTimestamp = "http://build.example.com/jenkins/job/#{projectName}/lastStableBuild/buildTimestamp"
    outputUrl="#{ENV['BUILD_URL']}/console"
    infoPlistPath="#{workspace}/#{xcodeDir}/#{xcodeDir}/#{xcodeDir}-Info.plist"
    displayName="#{projName}"
    if ENV['displayName'].to_s.strip.length > 0
      displayName=ENV['displayName']
    end  
    ipaPath="/notExist"
    provProfile="#{ENV['provisioningProfile']}.mobileprovision"
    provProfilePath="/Library/MobileDevice/ProvisioningProfiles/#{provProfile}"
    provProfile="#{ENV['provisioningProfile']}.mobileprovision"
    bundleIdentifierRelease="#{ENV['bundleIdentifierRelease']}"

  # gets commit messages since last sucessful build
    lastSuccessfulBuildTimeStamp=''
    if File.exist?(lastSuccessfulBuild)
      f = File.open(lastSuccessfulBuild, "r") 
      f.each_line do |line|
          lastSuccessfulBuildTimeStamp += line
      end
      f.close
    end  
    lastSuccessCommitLog=`git log --pretty="- %s (%an: %h)" --max-parents=1 --since="#{lastSuccessfulBuildTimeStamp}"`
    if lastSuccessCommitLog.to_s.strip.length == 0
      lastSuccessCommitLog = "no new commits to display"
    end  

        
  # if a step fails, it switches error to 1 and sets a brief message. all steps require 
  # error==0 to run except for send failure email.
    error=0      
    
    
# searches the root folder of the repo to find the .xcodeproj path 
# and sets the xcodeproj name, scheme and target
    xcodeprojPath=`find #{workspace}/#{xcodeDir} -name *.xcodeproj -maxdepth 1`
    xcodeprojPath=xcodeprojPath.gsub(/\s+/, "")
    if File.exist?(xcodeprojPath)
      xcodeproj=File.basename(xcodeprojPath)      
    else
      message="xcode project cannot be found"
      error=1
    end  


# reads info from info.plist and injects build number and display name
     if error==0
      if File.exist?(infoPlistPath) 
      # reads info.plist
        plistHash=Plist::parse_xml("#{infoPlistPath}")

      # sets varibles from info.plist
        bundleVersion=plistHash['CFBundleVersion']
        bundleVersion="#{bundleVersion}.#{buildNumber}"
        bundleIdentifier=plistHash['CFBundleIdentifier'].to_s
        bundleShortVersionString=plistHash['CFBundleShortVersionString'].to_s
        bundleVersion="#{bundleShortVersionString}.#{buildNumber}"
        bundleVersion=bundleVersion.gsub(" ","")
       
      # injects build number and display name into info.plist
        plistHash = Plist::parse_xml("#{infoPlistPath}")
        plistHash['CFBundleVersion']="#{bundleVersion}"
        #plistHash['CFBundleDisplayName']="#{displayName}"
        plistContent=plistHash.to_plist
        f = File.new(infoPlistPath, "w")
        f.puts plistContent
        f.close
      else
        message="info.plist cannot be found"
        error=1
      end
    end  
 
    
# builds adhoc build configuration and outputs .app and .dSYM in the root of the workspace
    if error==0
      if ENV['configuration'] == "Adhoc" || ENV['configuration'] == "AdHoc"
        buildPath=File.join(workspace,"build","#{configuration}-iphoneos")
        if ENV['buildWorkspace'] == "Yes"
          puts "build command: cd #{xcodeDir}; xcodebuild -workspace #{xcworkspace}.xcworkspace -scheme #{scheme} -configuration #{configuration} -sdk iphoneos CONFIGURATION_BUILD_DIR=#{workspace}"
          output=`cd #{xcodeDir}; xcodebuild -workspace #{xcworkspace}.xcworkspace -scheme #{scheme} -configuration #{configuration} -sdk iphoneos CONFIGURATION_BUILD_DIR=#{workspace}`
        else
          puts "build command: cd #{xcodeDir}; xcodebuild -configuration #{configuration} -sdk iphoneos -target #{target} CONFIGURATION_BUILD_DIR=#{workspace}"
          output=`cd #{xcodeDir}; xcodebuild -configuration "#{configuration}" -sdk iphoneos -target #{target} CONFIGURATION_BUILD_DIR=#{workspace}`
        end
        success=0
        success=1 if output.include?("** BUILD SUCCEEDED **")
        if output.include?("** BUILD SUCCEEDED **")
          puts "(** FINISHED BUILDING ADHOC **)"
          puts output
          puts "---------------------"
        elsif output.include?("** BUILD FAILED **")
          puts "(** FAILED BUILDING ADHOC **)"
          puts output 
          puts "---------------------"
          error=1
          message="unable to build adhoc. check build output for errors"
        end  
      end
    end  


# archives project in the build server's xcode organizer. requires xcodeproj, and scheme to run.
    if error==0
      if ENV['configuration'] == "Release"
        archiveStartedTime=Time.now 
        puts "cd #{xcodeDir}; xcodebuild -workspace #{xcworkspace}.xcworkspace -scheme #{scheme} -configuration Release archive"
        output=`cd #{xcodeDir}; xcodebuild -workspace #{xcworkspace}.xcworkspace -scheme #{scheme} -configuration Release archive`
        puts output
        archivePath=Dir.glob("#{archivesPath}/*/**").max_by {|f| File.mtime(f)}
        archiveDate=File.mtime(archivePath)
        archivePath=archivePath.gsub(" ","\\ ")
        success=0
        success=1 if archiveStartedTime < archiveDate
        if success==1
          puts "(** FINISHED BUILDING ARCHIVE **)"
          puts output
          puts "---------------------"
        else
          puts "(** FAILED BUILDING ARCHIVE **)"
          puts output 
          puts "---------------------"
          error=1
          message="unable to build archive. check build output for errors"
        end
      end     
    end

	
# searches the root of the workspace for the .app path for an adhoc build
    if error==0
        if ENV['configuration'] == "Adhoc" || ENV['configuration'] == "AdHoc"
          appPath=`find #{workspace} -name *.app -maxdepth 1`
          appPath=appPath.gsub(/\s+/, "")
           if File.exist?(appPath)    
           else
             message="cannot find .app"
             error=1
           end
        end   
    end 
  
   
 # sets paths for the release archive
    if error==0
        if ENV['configuration'] == "Release"
          archivesPath="/Users/Shared/Jenkins/Archives/"
          archivePath=Dir.glob("#{archivesPath}/*/**").max_by {|f| File.mtime(f)}
          archiveDate=File.mtime(archivePath)
          archivePath=archivePath.gsub(" ","\\ ").to_s
          appPath=`find #{archivePath}/Products/Applications -name *.app -maxdepth 1`
          appPath.to_s
          appPath=appPath.gsub(" ","\\ ").to_s
          appPath=appPath.gsub(/\n+/, "")
          configuration="Adhoc"
          puts "releaseAppPath: #{appPath}"
        end  
    end


# builds ipa with embedded profile
    if error==0
          ipaName="#{jobName}-#{bundleVersion}.ipa"
          ipaPath="#{workspace}/#{ipaName}"
          profileConfig="#{configuration}"

        # builds ipa with embedded profile in workspace root and puts the build output in jenkins' console output
          command="/usr/bin/xcrun -sdk iphoneos PackageApplication -v #{appPath} -o \"#{ipaPath}\" --sign \"#{codeSigningIdentity}\" --embed \"#{provProfilePath}\""
          puts command
          output= `#{command}`
          puts "(** FINISHED BUILDING IPA **)"
          puts output
          f = File.new(lastSuccessfulBuild, "w")
          f.puts buildStartedTime
          f.close
        else
          puts "(** FAILED BUILDING IPA **)"
          puts output
          message="unable to build ipa. check build output for errors"
          error=1
    end  


# builds the manifest-plist from a prefab and enters info from post-inject info.plist
  if File.exist?(ipaPath)
    if error==0

    # sets manifest.plist path and name
      manifestName="#{jobName}-#{bundleVersion}.plist";
      manifestPath=File.join(workspace, manifestName)

    # modifies manifest.plist with data from info.plist
      plistHash = Plist::parse_xml(prefabPath)
      plistHash['items'][0]['metadata']['bundle-identifier']=bundleIdentifier
      plistHash['items'][0]['metadata']['bundle-version']=bundleVersion
      plistHash['items'][0]['metadata']['title']="#{displayName}"
      plistHash['items'][0]['metadata']['subtitle']="#{hockeykitVersionCap} ##{buildNumber}"

    # saves manifest.plist
      plistContent=plistHash.to_plist
      f = File.new(manifestPath, "w")
      f.puts plistContent
      f.close
    end  
  else
    message="cannot find .ipa. unable to build manifest.plist"
    error=1
  end  


# makes directory and copies manifest and ipa to hockeykit server
    if error==0
      # set paths and folder names
        installAppFolder="#{bundleIdentifier}.#{hockeykitVersion}"
        installBuildFolder="build-#{buildNumber}"
        installDiskPath=File.join(installDiskRootPath, installAppFolder)
        installDiskPathBuild=File.join(installDiskPath, installBuildFolder)

      # creates app dir on install server if it doesn't exist
        `mkdir -p #{installDiskPath}`

      # creates build dir on install server if it doesn't exist
        `mkdir -p #{installDiskPathBuild}`

      # copies ipa to install server
        `cp #{ipaPath} #{installDiskPathBuild}/#{ipaName}`

      # copies the profile to install server
        `cp #{provProfilePath} #{installDiskPath}/#{provProfile}`
        puts "copying provProfile cp #{provProfilePath} #{installDiskPath}/#{provProfile}"

      # copies manifest.plist to install server. copies after ipa so it won't show up in hockeykit until ipa upload is complete
        `cp #{manifestPath} #{installDiskPathBuild}/#{manifestName}`
        puts " "
        puts "---------------------"
        puts " "
        puts "Finished building and uploading #{ipaName} and #{manifestName} to install server"
        puts " "
        puts "---------------------"
        puts " "
        message="ipa generated and uploaded to install successfully!"
    end 
 
    
# sends success email if error==0
if error==0
body=<<EOF
iOS Builds has finished building #{displayName} v#{bundleVersion}!

build server install options:
http://build.example.com

install on your device:
itms-services://?action=download-manifest&url=http%3A%2F%2Fbuild.example.com%2Finstall%2Fapi%2F2%2Fapps%2F#{installAppFolder}%3Fformat%3Dplist

commits since last successful build:
#{lastSuccessCommitLog}

EOF
      if ENV['configuration'] == "Release"
        subject="SUCCESS! #{displayName} v#{bundleVersion} Release finished building and uploading!"
      else
        subject="SUCCESS! #{displayName} v#{bundleVersion} finished building and uploading!"
      end  
      emailHandler.sendMail(successEmail,subject,body)
      puts "(** SENDING BUILD SUCCEEDED EMAIL **)"
      puts "build succeeded!"
end


# sends failure email if error==1
if error==1
body=<<EOF
iOS Builds has failed building #{displayName} v#{bundleVersion}!

error message: #{message}

build output url: 
#{outputUrl}

job url:
#{jobUrl}
EOF
    if ENV['configuration'] == "Release"
      subject="**FAILED** #{displayName} v#{bundleVersion} Release!"
    else
      subject="**FAILED** #{displayName} v#{bundleVersion}!"
    end
    emailHandler.sendMail(failureEmail,subject,body)
    puts "(** SENDING BUILD FAILED EMAIL **)"
    puts "build failed: #{message}"
    exit
end