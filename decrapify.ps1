#Windows 10 Decrapifier 18XX/19XX/20XX
#By CSAND
#July 6 2021

#PURPOSE: Eliminate much of the bloat that comes with Windows 10. Change many privacy settings to be off by default. Remove built-in advertising, Cortana, OneDrive, Cortana stuff (all optional). Disable some data collection.
#		  Clean up the start menu for new user accounts. Remove a bunch of pre-installed apps, or all of them (including the store). Create a more professional looking W10 experience. Changes some settings no longer
#         available via GPO for Professional edition.  All of this without breaking Windows.
#
#DISCLAIMER: Most of the changes are easily undone, but some like removing the store are difficult to undo.  You should use local/group policy to remove the store if you want.
#			 The -allapps switch is there but I do not recommend most people use it.
#			 I encourage you to research these changes beforehand, and read through the script.
#         	 Each section is described with comments, to make it easier to see what's going on.
#
#		  
#INSTRUCTIONS: For best results use the following how-tos. Running from an existing profile on an "in-use" machine won't affect any already-existing user profiles and won't give the best results.
#			   Read through the script to see what is disabled, and comment out anything you want to keep. By default a transcript is saved at SYSTEMDRIVE\WindowsDCtranscript.txt.
#
#Single machine how-to:
#https://community.spiceworks.com/how_to/148624-how-to-clean-up-a-single-windows-10-machine-image-using-decrapifier
#
#Basic MDT how-to:
#https://community.spiceworks.com/how_to/150455-shoehorn-decrapifier-into-your-mdt-task
#
#
#Join the Spiceworks Decrapifier community group on Spiceworks! 
#https://community.spiceworks.com/user-groups/windows-decrapifier-group
#
#Common questions/issues:
#https://community.spiceworks.com/topic/2149611-common-questions-and-problems?page=1#entry-7850320
#
#
#OFFICIAL DOWNLOAD:
#https://community.spiceworks.com/scripts/show/4378-windows-10-decrapifier-1803
#This is the only place I post any updates to this script.
#
#Changelog:
#https://community.spiceworks.com/topic/2162951-changelog
#
#Previous versions:
#https://community.spiceworks.com/scripts/show/3977-windows-10-decrapifier-1709
#https://community.spiceworks.com/scripts/show/3298-windows-10-decrapifier-version-1
#
#
#
#***Switches***
# 
#Switch         Function
#---------------------------
#No switches 	Disables unnecessary services and scheduled tasks. Removes all UWP apps except for some useful ones. Disables Cortana, OneDrive, restricts default privacy settings and cleans up the default start menu.
#-AllApps       Removes ALL apps including the store. Make sure this is what you want before you do it. It can be tough to get the store back. Seriously, don't do this unless you are 100% certain.
#-LeaveTasks    Leaves scheduled tasks alone.
#-LeaveServices Leaves services alone.
#-AppAccess		By default this script will restrict almost all the permissions in Settings -> Privacy. This will prevent that from happening.
#-ClearStart    Empties the start menu completely leaving you with just the apps list.
#-OneDrive		Leaves OneDrive and Onedrive for Business fully functional.
#-Tablet		Use this for tablets or 2-in-1s to leave location and sensors enabled.
#-Cortana		Leave Cortana and web enabled search intact... if that's what you really want.
#-Xbox			Leave xBox apps and related items.
#-NoLog			Don't copy transcript to systemdrive\WindowsDCtranscript.txt.
#-AppsOnly      Only removes apps, doesn't touch privacy settings, services, and scheduled tasks. Cannot be used with -SettingsOnly switch. Can be used with all the others.
#-SettingsOnly  Only adjusts privacy settings, services, and scheduled tasks. Leaves apps. Cannot be used with -AppsOnly switch.  Can be used with all others (-AllApps won't do anything in that case, obviously).


[cmdletbinding(DefaultParameterSetName="Decrapifier")]
param (
[switch]$AllApps, 
  [switch]$LeaveTasks,
  [switch]$LeaveServices,
[switch]$AppAccess,
[switch]$OneDrive,
[switch]$Xbox,
[switch]$Tablet,
[switch]$Cortana,
  [switch]$ClearStart,
[switch]$NoLog,
  [Parameter(ParameterSetName="AppsOnly")]
  [switch]$AppsOnly,
  [Parameter(ParameterSetName="SettingsOnly")]
  [switch]$SettingsOnly
)

#------USER EDITABLE VARIABLES - change these to your tastes!------

#Apps to keep. Wildcard is implied so try to be specific enough to not overlap with apps you do want removed. 
#Make sure not begin or end with a "|". ex: "app|app2" - good. "|app|app2|" - bad.

$GoodApps =	"calculator|store|mspaint|terminal|ubuntu|radeon"

#Start Menu XML. If you run the script without -ClearStart, the XML below will be used for a custom start layout. By default it just leaves File Explorer, classic Control Panel, and Snipping Tool tiles.
#Place your XML like so:
#	$StartLayourStr = @"
#	<**YOUR START LAYOUT XML**>
#	"@

$StartLayoutStr = @" 
<LayoutModificationTemplate Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
<LayoutOptions StartTileGroupCellWidth="6" />
<DefaultLayoutOverride>
  <StartLayoutCollection>
    <defaultlayout:StartLayout GroupCellWidth="6" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout">
      <start:Group Name="" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout">
        <start:DesktopApplicationTile Size="2x2" Column="0" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\File Explorer.lnk" />
        <start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Accessories\Snipping Tool.lnk" />
    <start:DesktopApplicationTile Size="2x2" Column="0" Row="2" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\Control Panel.lnk" />
      </start:Group>
    </defaultlayout:StartLayout>
  </StartLayoutCollection>
</DefaultLayoutOverride>
</LayoutModificationTemplate>
"@

#------End editable variables------


#---Functions---

#Appx removal
#Removes all apps or some apps depending on switches used.

Function RemoveApps {
#SafeApps contains apps that shouldn't be removed, or just can't and cause errors
$SafeApps = "AAD.brokerplugin|accountscontrol|apprep.chxapp|assignedaccess|asynctext|bioenrollment|capturepicker|cloudexperience|contentdelivery|desktopappinstaller|ecapp|edge|extension|getstarted|immersivecontrolpanel|lockapp|net.native|oobenet|parentalcontrols|PPIProjection|search|sechealth|secureas|shellexperience|startmenuexperience|vclibs|xaml|XGpuEject"
If ($Xbox) {
  $SafeApps = "$SafeApps|Xbox" 
}

If ($Allapps) {
  $RemoveApps = Get-AppxPackage -allusers | where-object {$_.name -notmatch $SafeApps}
  $RemovePrApps = Get-AppxProvisionedPackage -online | where-object {$_.displayname -notmatch $SafeApps}
    ForEach ($RemovedApp in $RemoveApps) {
      Write-Host Removing app package: $RemovedApp.name
      Remove-AppxPackage -package $RemovedApp -erroraction silentlycontinue
      
}			ForEach ($RemovedPrApp in $RemovePrApps) {
      Write-Host Removing provisioned app $RemovedPrApp.displayname
      Remove-AppxProvisionedPackage -online -packagename $RemovedPrApp.packagename -erroraction silentlycontinue
      
}
}	Else {
  $SafeApps = "$SafeApps|$GoodApps"
  $RemoveApps = Get-AppxPackage -allusers | where-object {$_.name -notmatch $SafeApps}
  $RemovePrApps = Get-AppxProvisionedPackage -online | where-object {$_.displayname -notmatch $SafeApps}
    ForEach ($RemovedApp in $RemoveApps) {
      Write-Host Removing app package: $RemovedApp.name
      Remove-AppxPackage -package $RemovedApp -erroraction silentlycontinue
      
}			ForEach ($RemovedPrApp in $RemovePrApps) {
      Write-Host Removing provisioned app $RemovedPrApp.displayname
      Remove-AppxProvisionedPackage -online -packagename $RemovedPrApp.packagename -erroraction silentlycontinue
      
}
}
} 
#End Function RemoveApps
  

#Disable scheduled tasks
#Tasks: Various CEIP and information gathering/sending tasks.
Function DisableTasks {
  If ($LeaveTasks) {
      Write-Host "***Leavetasks switch set - leaving scheduled tasks alone...***" 
}    Else {
      Write-Host "***Disabling some unecessary scheduled tasks...***"
      Get-Scheduledtask "Microsoft Compatibility Appraiser","ProgramDataUpdater","Consolidator","KernelCeipTask","UsbCeip","Microsoft-Windows-DiskDiagnosticDataCollector","GatherNetworkInfo","QueueReporting" -erroraction silentlycontinue | Disable-scheduledtask 
}
}


#Disable services
Function DisableServices {
  If ($LeaveServices) {
      Write-Host "***Leaveservices switch set - leaving services alone...***"
}    Else {
      Write-Host "***Stopping and disabling some services...***"
      #Diagnostics tracking WMP Network Sharing
  Get-Service Diagtrack,WMPNetworkSvc -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
  #WAP Push Message Routing  NOTE Sysprep w/ Generalize WILL FAIL if you disable the DmwApPushService. Commented out by default.
  Get-Service DmwApPushService -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
  #Disable OneSync service - Used to sync various apps and settings if you enable that (contacts, etc). Commented out by default to not break functionality.
  Get-Service OneSyncSvc | stop-service -passthru | set-service -startuptype disabled
  
  #xBox services
  If ($Xbox){
}		 Else {
    #Disable xBox services - "xBox Game Monitoring Service" - XBGM - Can't be disabled (access denied)
    Get-Service XblAuthManager,XblGameSave,XboxNetApiSvc -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
}		
}
}

      
#Registry change functions
#Load default user hive
Function loaddefaulthive {
$matjazp72 = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' Default).Default
  reg load "$reglocation" $matjazp72\ntuser.dat
}


#Unload default user hive
Function unloaddefaulthive {
  [gc]::collect()
  reg unload "$reglocation"
}


#Cycle registry locations - 1st pass HKCU, 2nd pass default NTUSER.dat
Function RegChange {
  Write-Host "***Applying registry items to HKCU...***"
  $reglocation = "HKCU"
  regsetuser
  $reglocation = "HKLM\AllProfile"
Write-Host "***Applying registry items to default NTUSER.DAT...***"
  loaddefaulthive; regsetuser; unloaddefaulthive
  $reglocation = $null
Write-Host "***Applying registry items to HKLM...***"
  regsetmachine
  Write-Host "***Registry set current user and default user, and policies set for local machine!***"
}


#Set current and default user registry settings
Function RegSetUser {
  #Start menu suggestions
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SystemPaneSuggestionsEnabled" /D 0 /F
#Show suggested content in settings
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-338393Enabled" /D 0 /F
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-353694Enabled" /D 0 /F
#Show suggestions occasionally
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-338388Enabled" /D 0 /F
#Multitasking - Show suggestions in timeline
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-353698Enabled" /D 0 /F
  #Lockscreen suggestions, rotating pictures
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SoftLandingEnabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "RotatingLockScreenEnabled" /D 0 /F
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "RotatingLockScreenOverlayEnabled" /D 0 /F
  #Preinstalled apps, Minecraft Twitter etc all that - still need a clean default start menu to fully eliminate
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "PreInstalledAppsEnabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "PreInstalledAppsEverEnabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "OEMPreInstalledAppsEnabled" /D 0 /F
  #MS shoehorning apps quietly into your profile
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SilentInstalledAppsEnabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "ContentDeliveryAllowed" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContentEnabled" /D 0 /F
  #Ads in File Explorer
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /T REG_DWORD /V "ShowSyncProviderNotifications" /D 0 /F
#Show me the Windows welcome experience after updates and occasionally
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-310093Enabled" /D 0 /F
#Get tips, tricks, suggestions as you use Windows 
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-338389Enabled" /D 0 /F

#Privacy Settings
#Let websites provide local content by accessing language list - appears to reset during OOBE.
#Reg Add "$reglocation\Control Panel\International\User Profile" /T REG_DWORD /V "HttpAcceptLanguageOptOut" /D 1 /F
  #Ask for feedback
  Reg Add "$reglocation\SOFTWARE\Microsoft\Siuf\Rules" /T REG_DWORD /V "NumberOfSIUFInPeriod" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Siuf\Rules" /T REG_DWORD /V "PeriodInNanoSeconds" /D 0 /F
#Let apps use advertising ID
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /T REG_DWORD /V "Enabled" /D 0 /F
#Let Windows track app launches to improve start and search results - includes run history
#Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /T REG_DWORD /V "Start_TrackProgs" /D 0 /F
#Tailored experiences - Diagnostics & Feedback settings
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" /T REG_DWORD /V "TailoredExperiencesWithDiagnosticDataEnabled" /D 0 /F
#Let apps on other devices open messages and apps on this device - Shared Experiences settings
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /T REG_DWORD /V "RomeSdkChannelUserAuthzPolicy" /D 0 /F
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /T REG_DWORD /V "CdpSessionUserAuthzPolicy" /D 0 /F

#Speech Inking & Typing - comment out if you use the pen\stylus a lot
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language" /T REG_DWORD /V "Enabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\InputPersonalization" /T REG_DWORD /V "RestrictImplicitTextCollection" /D 1 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\InputPersonalization" /T REG_DWORD /V "RestrictImplicitInkCollection" /D 1 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" /T REG_DWORD /V "HarvestContacts" /D 0 /F
Reg Add "$reglocation\SOFTWARE\Microsoft\Personalization\Settings" /T REG_DWORD /V "AcceptedPrivacyPolicy" /D 0 /F
#Improve inking & typing recognition
Reg Add "$reglocation\SOFTWARE\Microsoft\Input\TIPC" /T REG_DWORD /V "Enabled" /D 0 /F
#Pen & Windows Ink - Show recommended app suggestions
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace" /T REG_DWORD /V "PenWorkspaceAppSuggestionsEnabled" /D 0 /F

#People + Feeds
#Show My People notifications
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People\ShoulderTap" /T REG_DWORD /V "ShoulderTap" /D 0 /F
#Show My People app suggestions
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-314563Enabled" /D 0 /F
#People on Taskbar
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /T REG_DWORD /V "PeopleBand" /D 0 /F
#News/Feeds taskbar item
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /T REG_DWORD /V "ShellFeedsTaskbarViewMode" /D 2 /F
  
#Other Settings
#Use Autoplay for all media and devices
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /T REG_DWORD /V "DisableAutoplay" /D 1 /F
#Taskbar search, personal preference. 0 = no search, 1 = search icon, 2 = search bar
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "SearchboxTaskbarMode" /D 0 /F
#Allow search to use location if it's enabled
Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "AllowSearchToUseLocation" /D 0 /F
#Do not track - Edge
Reg Add "$reglocation\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage\microsoft.microsoftedge_8wekyb3d8bbwe\MicrosoftEdge\Main" /T REG_DWORD /V "DoNotTrack" /D 1 /F
#Do not track - IE
Reg Add "$reglocation\SOFTWARE\Microsoft\Internet Explorer\Main" /T REG_DWORD /V "DoNotTrack" /D 1 /F

#--Optional User Settings--

  #App permissions user settings, these are all available from the settings menu
  If ($AppAccess) {
}	 Else{ 	
  #App permissions
  #Location - see tablet settings
  #Camera
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" /T REG_SZ /V "Value" /D Deny /F
  #Microphone
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /T REG_SZ /V "Value" /D Deny /F
  #Notifications - doesn't appear to work in 1803, setting hasn't been moved as of 1803 like most of the others
  #Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{52079E78-A92B-413F-B213-E8FE35712E72}" /T REG_SZ /V "Value" /D Deny /F
  #Account Info
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation" /T REG_SZ /V "Value" /D Deny /F
  #Contacts
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts" /T REG_SZ /V "Value" /D Deny /F	
  #Calendar
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments" /T REG_SZ /V "Value" /D Deny /F
  #Call history
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory" /T REG_SZ /V "Value" /D Deny /F
  #Email
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email" /T REG_SZ /V "Value" /D Deny /F
  #Tasks
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks" /T REG_SZ /V "Value" /D Deny /F
  #TXT/MMS
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat" /T REG_SZ /V "Value" /D Deny /F
  #Radios - doesn't appear to work in 1803, setting hasn't been moved as of 1803 like most of the others
  #Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{A8804298-2D5F-42E3-9531-9C8C39EB29CE}" /T REG_SZ /V "Value" /D Deny /F
  #Other Devices - reset during OOBE
  #Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\LooselyCoupled" /T REG_SZ /V "Value" /D Deny /F
  #Cellular Data
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\cellularData" /T REG_SZ /V "Value" /D Deny /F
  #Allow apps to run in background global setting - seems to reset during OOBE
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /T REG_DWORD /V "GlobalUserDisabled" /D 1 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "BackgroundAppGlobalToggle" /D 0 /F	
  #App Diagnostics - doesn't appear to work in 1803, setting hasn't been moved as of 1803 like most of the others
  #Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}" /T REG_SZ /V "Value" /D Deny /F
  #My Documents
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary" /T REG_SZ /V "Value" /D Deny /F
  #My Pictures
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary" /T REG_SZ /V "Value" /D Deny /F
  #My Videos
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary" /T REG_SZ /V "Value" /D Deny /F
  #File System
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess" /T REG_SZ /V "Value" /D Deny /F
  
  #Tablet Settings - use -Tablet switch to leave these on
  If ($Tablet) {
}
   Else {
    #Deny access to location and sensors
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /T REG_DWORD /V "SensorPermissionState" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /T REG_SZ /V "Value" /D Deny /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E6AD100E-5F4E-44CD-BE0F-2265D88D14F5}" /T REG_SZ /V "Value" /D Deny /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /T REG_SZ /V "Value" /D Deny /F
}
  
}

#Disable Cortana - use -Cortana to leave it on
If ($Cortana){
}	 Else{
  #Disable Cortana and Bing search user settings
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CortanaEnabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CanCortanaBeEnabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "DeviceHistoryEnabled" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CortanaConsent" /D 0 /F
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CortanaInAmbientMode" /D 0 /F
  #Disable Bing search from start menu/search bar
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "BingSearchEnabled" /D 0 /F
  #Disable Cortana on lock screen
  Reg Add "$reglocation\SOFTWARE\Microsoft\Speech_OneCore\Preferences" /T REG_DWORD /V "VoiceActivationEnableAboveLockscreen" /D 0 /F
  #Disable Cortana search history
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "HistoryViewEnabled" /D 0 /F
}
  
#Game settings - use -Xbox to leave these on
If ($Xbox) {
}	 Else {
  #Disable Game DVR
  Reg Add "$reglocation\System\GameConfigStore" /T REG_DWORD /V "GameDVR_Enabled" /D 0 /F
}

#OneDrive settings - use -OneDrive switch to leave these on
If ($OneDrive) {
}	 Else {
  #Disable OneDrive startup run user settings
  Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /T REG_BINARY /V "OneDrive" /D 0300000021B9DEB396D7D001 /F
  #Disable automatic OneDrive desktop setup for new accounts
  If ($reglocation -ne "HKCU") {
    Reg Delete "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /V "OneDriveSetup" /F
}
}

#End user registry settings
}


#Set local machine settings and local group policies    
Function RegSetMachine {
  #--Local GP settings--   CONVERT THESE TO HKCU / DEFAULT / HKLM WHERE POSSIBLE
  #Can be adjusted in GPedit.msc in Pro+ editions.
  #Local Policy\Computer Config\Admin Templates\Windows Components			
  #/Application Compatibility
  #Turn off Application Telemetry			
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /T REG_DWORD /V "AITEnable" /D 0 /F			
  #Turn off inventory collector			
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /T REG_DWORD /V "DisableInventory" /D 1 /F

  #/Cloud Content			
  #Turn off Consumer Experiences	- Enterprise only (for Pro, HKCU settings and start menu cleanup achieve same result)		
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /T REG_DWORD /V "DisableWindowsConsumerFeatures" /D 1 /F
#Turn off all spotlight features	
  #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /T REG_DWORD /V "DisableWindowsSpotlightFeatures" /D 1 /F  

  #/Data Collection and Preview Builds			
  #Set Telemetry to off (switches to 1:basic for W10Pro and lower)			
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /T REG_DWORD /V "AllowTelemetry" /D 0 /F
  #Disable pre-release features and settings			
  #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds" /T REG_DWORD /V "EnableConfigFlighting" /D 0 /F
  #Do not show feedback notifications			
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /T REG_DWORD /V "DoNotShowFeedbackNotifications" /D 1 /F

  #/Store
  #Disable all apps from store, commented out by default as it will break the store			
  #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /T REG_DWORD /V "DisableStoreApps" /D 1 /F		
  #Turn off Store, left disabled by default			
  #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /T REG_DWORD /V "RemoveWindowsStore" /D 1 /F

  #/Sync your settings - commented out by default to keep functionality of sync service		
  #Do not sync (anything)			
  #Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /T REG_DWORD /V "DisableSettingSync" /D 2 /F
  #Disallow users to override this
  #Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /T REG_DWORD /V "DisableSettingSyncUserOverride" /D 1 /F

#Add "Run as different user" to context menu
Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /T REG_DWORD /V "ShowRunasDifferentuserinStart" /D 1 /F

#Disable "Meet Now" taskbar button
Reg Add	"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /T REG_DWORD /V "HideSCAMeetNow" /D 1 /F

#!!!None of these effective anymore in 1803!!! Now handled by HKCU settings
  #Disallow web search from desktop search			
  #Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "DisableWebSearch" /D 1 /F
  #Don't search the web or display web results in search			
  #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "ConnectedSearchUseWeb" /D 0 /F
#Don't allow search to use location
#Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "AllowSearchToUseLocation" /D 0 /F

  #/Windows Update			
  #Turn off featured SOFTWARE notifications through Windows Update
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /T REG_DWORD /V "EnableFeaturedSoftware" /D 0 /F

  #--Non Local GP Settings--		
  #Delivery Optimization settings - sets to 1 for LAN only, change to 0 for off
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /T REG_DWORD /V "DownloadMode" /D 1 /F
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /T REG_DWORD /V "DODownloadMode" /D 1 /F
Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" /T REG_DWORD /V "DownloadMode" /D 1 /F

  #Disabling advertising info and device metadata collection for this machine
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /T REG_DWORD /V "Enabled" /D 0 /F
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" /V "PreventDeviceMetadataFromNetwork" /T REG_DWORD /D 1 /F

#Disable CEIP. GP setting at: Computer Config\Admin Templates\System\Internet Communication Managemen\Internet Communication settings
  Reg Add "HKLM\SOFTWARE\Microsoft\SQMClient\Windows" /T REG_DWORD /V "CEIPEnable" /D 0 /F

#Turn off automatic download/install of store app updates	
  #Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" /T REG_DWORD /V "AutoDownload" /D 2 /F	

#Prevent using sign-in info to automatically finish setting up after an update
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /T REG_DWORD /V "ARSOUserConsent" /D 0 /F

  #Prevent apps on other devices from opening apps on this one - disables phone pairing
  #Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SmartGlass" /T REG_DWORD /V "UserAuthPolicy" /D 0 /F
  
  #Enable diagnostic data viewer
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey" /T REG_DWORD /V "EnableEventTranscript" /D 1 /F

#Disable Edge desktop shortcut
Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /T REG_DWORD /V "DisableEdgeDesktopShortcutCreation" /D 1 /F

#Filter web content through smartscreen. Left enabled by default.
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /T REG_DWORD /V "EnableWebContentEvaluation" /D 0 /F

#--Optional Machine Settings--

#Disable Cortana - use -Cortana to leave it on
If ($Cortana){
}	 Else{
  #Cortana local GP - Computer Config\Admin Templates\Windows Components\Search			
  #Disallow Cortana			
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "AllowCortana" /D 0 /F
  #Disallow Cortana on lock screen - seems pointless with above setting, may be deprecated, covered by HKCU anyways		
  #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "AllowCortanaAboveLock" /D 0 /F
}

#Tablet Settings - use -Tablet switch to leave these on
If ($Tablet) {
}	 Else {
  #Turn off location - global
  Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /T REG_SZ /V "Value" /D Deny /F
}

#Game settings - use -Xbox to leave these on
If ($Xbox) {
}	 Else {
  #Disable Game Monitoring Service
  Reg Add "HKLM\SYSTEM\CurrentControlSet\Services\xbgm" /T REG_DWORD /V "Start" /D 4 /F
  #GameDVR local GP - Computer Config\Admin Templates\Windows Components\Windows Game Recording and Broadcasting
  Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /T REG_DWORD /V "AllowGameDVR" /D 0 /F
}

#OneDrive settings - use -OneDrive switch to leave these on
If ($OneDrive) {
}	 Else {
  #Prevent usage of OneDrive local GP - Computer Config\Admin Templates\Windows Components\OneDrive	
  Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /T REG_DWORD /V "DisableFileSyncNGSC" /D 1 /F
  Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /T REG_DWORD /V "DisableFileSync" /D 1 /F
  #Remove OneDrive from File Explorer
  Reg Add "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /T REG_DWORD /V "System.IsPinnedToNameSpaceTree" /D 0 /F
  Reg Add "HKCR\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /T REG_DWORD /V "System.IsPinnedToNameSpaceTree" /D 0 /F
}

#End machine registry settings
}           


#Clean up the default start menu    
Function ClearStartMenu {
  If ($ClearStart) {
  Write-Host "***Setting empty start menu for new profiles...***"
#Don't edit this. Creates empty start menu if -ClearStart is used.
      $StartLayoutStr = @"
<LayoutModificationTemplate Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout">
<LayoutOptions StartTileGroupCellWidth="6" />
<DefaultLayoutOverride>
  <StartLayoutCollection>
    <defaultlayout:StartLayout GroupCellWidth="6" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout">
    </defaultlayout:StartLayout>
  </StartLayoutCollection>
</DefaultLayoutOverride>
</LayoutModificationTemplate>
"@
    add-content $Env:TEMP\startlayout.xml $StartLayoutStr
      import-startlayout -layoutpath $Env:TEMP\startlayout.xml -mountpath $Env:SYSTEMDRIVE\
      remove-item $Env:TEMP\startlayout.xml
}    Else {        
  Write-Host "***Setting clean start menu for new profiles...***"
#Custom start layout XML near the top of the script.

      add-content $Env:TEMP\startlayout.xml $StartLayoutStr
      import-startlayout -layoutpath $Env:TEMP\startlayout.xml -mountpath $Env:SYSTEMDRIVE\
      remove-item $Env:TEMP\startlayout.xml
}
}


#Goodbye Message Function
Function Goodbye {
  Write-Host "*******Decrapification complete.*******"
Write-Host "*******Remember to set your execution policy back!  Set-Executionpolicy restricted is the Windows 10 default.*******"
  Write-Host "*******Reboot your computer now!*******"     
}

#Chris Bensch additions from other scripts Function
Function CBAdds {
# Cut out redundanct stuff because of updated decrapify.ps1
# Disable Wi-Fi Sense
Write-Host "Disabling Wi-Fi Sense..."
If (!(Test-Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting")) {
	New-Item -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "Value" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Type DWord -Value 0

# Enable Wi-Fi Sense
# Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "Value" -Type DWord -Value 1
# Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Type DWord -Value 1

# Disable SmartScreen Filter - Duplicate
Write-Host "Disabling SmartScreen Filter..."
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Type String -Value "Off"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation" -Type DWord -Value 0

# Enable SmartScreen Filter
# Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Type String -Value "RequireAdmin"
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation"

# Disable Location Tracking
Write-Host "Disabling Location Tracking..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Type DWord -Value 0

# Enable Location Tracking
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 1
# Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Type DWord -Value 1

# Disable Feedback
Write-Host "Disabling Feedback..."
If (!(Test-Path "HKCU:\Software\Microsoft\Siuf\Rules")) {
	New-Item -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Type DWord -Value 0

# Enable Feedback
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod"

# Disable Advertising ID
Write-Host "Disabling Advertising ID..."
If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) {
	New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" | Out-Null
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Type DWord -Value 0

# Enable Advertising ID
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled"

# Remove AutoLogger file and restrict directory
Write-Host "Removing AutoLogger file and restricting directory..."
$autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
If (Test-Path "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl") {
	Remove-Item "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl"
}
icacls $autoLoggerDir /deny SYSTEM:`(OI`)`(CI`)F | Out-Null

# Unrestrict AutoLogger directory
# $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
# icacls $autoLoggerDir /grant:r SYSTEM:`(OI`)`(CI`)F | Out-Null

# Stop and disable Diagnostics Tracking Service
Write-Host "Stopping and disabling Diagnostics Tracking Service..."
Stop-Service "DiagTrack"
Set-Service "DiagTrack" -StartupType Disabled

# Enable and start Diagnostics Tracking Service
# Set-Service "DiagTrack" -StartupType Automatic
# Start-Service "DiagTrack"

##########
# Service Tweaks
##########

# Disable Windows Update automatic restart
Write-Host "Disabling Windows Update automatic restart..."
Set-ItemProperty -Path "HKLM:\Software\Microsoft\WindowsUpdate\UX\Settings" -Name "UxOption" -Type DWord -Value 1

# Enable Windows Update automatic restart
# Set-ItemProperty -Path "HKLM:\Software\Microsoft\WindowsUpdate\UX\Settings" -Name "UxOption" -Type DWord -Value 0

# Disable Remote Assistance
Write-Host "Disabling Remote Assistance..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 0

# Disable Remote Desktop
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Type DWord -Value 1

##########
# UI Tweaks
##########

# Disable Sticky keys prompt
Write-Host "Disabling Sticky keys prompt..."
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506"

# Enable Sticky keys prompt
# Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "510"

# Hide Search button / box
#Write-Host "Hiding Search Box / Button..."
#Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 0

# Show Search button / box
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode"

# Hide Task View button
# Write-Host "Hiding Task View button..."
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Type DWord -Value 0

# Show Task View button
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton"

# Show small icons in taskbar
# Write-Host "Showing small icons in taskbar..."
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarSmallIcons" -Type DWord -Value 1

# Show large icons in taskbar
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarSmallIcons"

# Show titles in taskbar
# Write-Host "Showing titles in taskbar..."
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarGlomLevel" -Type DWord -Value 1

# Hide titles in taskbar
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarGlomLevel"

# Show all tray icons
Write-Host "Showing all tray icons..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Type DWord -Value 0

# Hide tray icons as needed
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray"

# Show known file extensions
Write-Host "Showing known file extensions..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 0

# Hide known file extensions
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 1

# Show hidden files
# Write-Host "Showing hidden files..."
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 1

# Hide hidden files
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 2

# Change default Explorer view to "Computer"
Write-Host "Changing default Explorer view to `"Computer`"..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Type DWord -Value 1

# Change default Explorer view to "Quick Access"
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo"

# Show Computer shortcut on desktop
# Write-Host "Showing Computer shortcut on desktop..."
# If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu")) {
#	New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" | Out-Null
# }
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Type DWord -Value 0
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Type DWord -Value 0

# Hide Computer shortcut from desktop
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"

# Remove Desktop icon from computer namespace
# Write-Host "Removing Desktop icon from computer namespace..."
# Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" -Recurse -ErrorAction SilentlyContinue

# Add Desktop icon to computer namespace
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"

# Remove Documents icon from computer namespace
# Write-Host "Removing Documents icon from computer namespace..."
# Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" -Recurse -ErrorAction SilentlyContinue
# Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" -Recurse -ErrorAction SilentlyContinue

# Add Documents icon to computer namespace
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}"
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}"

# Remove Downloads icon from computer namespace
# Write-Host "Removing Downloads icon from computer namespace..."
# Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" -Recurse -ErrorAction SilentlyContinue
# Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" -Recurse -ErrorAction SilentlyContinue

# Add Downloads icon to computer namespace
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}"
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}"

# Remove Music icon from computer namespace
Write-Host "Removing Music icon from computer namespace..."
Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" -Recurse -ErrorAction SilentlyContinue

# Add Music icon to computer namespace
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}"
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}"

# Remove Pictures icon from computer namespace
# Write-Host "Removing Pictures icon from computer namespace..."
# Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" -Recurse -ErrorAction SilentlyContinue
# Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" -Recurse -ErrorAction SilentlyContinue

# Add Pictures icon to computer namespace
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}"
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}"

# Remove Videos icon from computer namespace
Write-Host "Removing Videos icon from computer namespace..."
Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" -Recurse -ErrorAction SilentlyContinue

# Add Videos icon to computer namespace
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}"
# New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}"

## Add secondary en-US keyboard
#Write-Host "Adding secondary en-US keyboard..."
#$langs = Get-WinUserLanguageList
#$langs.Add("en-US")
#Set-WinUserLanguageList $langs -Force

# Remove secondary en-US keyboard
# $langs = Get-WinUserLanguageList
# Set-WinUserLanguageList ($langs | ? {$_.LanguageTag -ne "en-US"}) -Force

# Uninstall Windows Media Player
# Write-Host "Uninstalling Windows Media Player..."
dism /online /Disable-Feature /FeatureName:MediaPlayback /Quiet /NoRestart

# Install Windows Media Player
# dism /online /Enable-Feature /FeatureName:MediaPlayback /Quiet /NoRestart

# Uninstall Work Folders Client
Write-Host "Uninstalling Work Folders Client..."
dism /online /Disable-Feature /FeatureName:WorkFolders-Client /Quiet /NoRestart

# Install Work Folders Client
# dism /online /Enable-Feature /FeatureName:WorkFolders-Client /Quiet /NoRestart

# Set Photo Viewer as default for bmp, gif, jpg and png
Write-Host "Setting Photo Viewer as default for bmp, gif, jpg, png and tif..."
If (!(Test-Path "HKCR:")) {
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}
ForEach ($type in @("Paint.Picture", "giffile", "jpegfile", "pngfile")) {
New-Item -Path $("HKCR:\$type\shell\open") -Force | Out-Null
New-Item -Path $("HKCR:\$type\shell\open\command") | Out-Null
Set-ItemProperty -Path $("HKCR:\$type\shell\open") -Name "MuiVerb" -Type ExpandString -Value "@%ProgramFiles%\Windows Photo Viewer\photoviewer.dll,-3043"
Set-ItemProperty -Path $("HKCR:\$type\shell\open\command") -Name "(Default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1"
}

# Remove or reset default open action for bmp, gif, jpg and png
# If (!(Test-Path "HKCR:")) {
# 	New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
# }
# Remove-Item -Path "HKCR:\Paint.Picture\shell\open" -Recurse
# Remove-ItemProperty -Path "HKCR:\giffile\shell\open" -Name "MuiVerb"
# Set-ItemProperty -Path "HKCR:\giffile\shell\open" -Name "CommandId" -Type String -Value "IE.File"
# Set-ItemProperty -Path "HKCR:\giffile\shell\open\command" -Name "(Default)" -Type String -Value "`"$env:SystemDrive\Program Files\Internet Explorer\iexplore.exe`" %1"
# Set-ItemProperty -Path "HKCR:\giffile\shell\open\command" -Name "DelegateExecute" -Type String -Value "{17FE9752-0B5A-4665-84CD-569794602F5C}"
# Remove-Item -Path "HKCR:\jpegfile\shell\open" -Recurse
# Remove-Item -Path "HKCR:\pngfile\shell\open" -Recurse

# Show Photo Viewer in "Open with..."
# Write-Host "Showing Photo Viewer in `"Open with...`""
# If (!(Test-Path "HKCR:")) {
# 	New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
# }
# New-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open\command" -Force | Out-Null
# New-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open\DropTarget" -Force | Out-Null
# Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open" -Name "MuiVerb" -Type String -Value "@photoviewer.dll,-3043"
# Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open\command" -Name "(Default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1"
# Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open\DropTarget" -Name "Clsid" -Type String -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"

# Remove Photo Viewer from "Open with..."
# If (!(Test-Path "HKCR:")) {
# 	New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
# }
# Remove-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open" -Recurse

# This script disables unwanted Windows services. If you do not want to disable
# certain services comment out the corresponding lines below.

$services = @(
    "diagnosticshub.standardcollector.service" # Microsoft (R) Diagnostics Hub Standard Collector Service
    "DiagTrack"                                # Diagnostics Tracking Service
    "dmwappushservice"                         # WAP Push Message Routing Service (see known issues)
    "lfsvc"                                    # Geolocation Service
    "MapsBroker"                               # Downloaded Maps Manager
    "NetTcpPortSharing"                        # Net.Tcp Port Sharing Service
    "RemoteAccess"                             # Routing and Remote Access
    "RemoteRegistry"                         # Remote Registry
    "SharedAccess"                             # Internet Connection Sharing (ICS)
    "TrkWks"                                   # Distributed Link Tracking Client
    "WbioSrvc"                               # Windows Biometric Service (required for Fingerprint reader / facial detection)
    #"WlanSvc"                                 # WLAN AutoConfig
    #"WMPNetworkSvc"                            # Windows Media Player Network Sharing Service
    #"wscsvc"                                  # Windows Security Center Service
    #"WSearch"                                 # Windows Search
    "XblAuthManager"                           # Xbox Live Auth Manager
    "XblGameSave"                              # Xbox Live Game Save Service
    "XboxNetApiSvc"                            # Xbox Live Networking Service
    "ndu"                                      # Windows Network Data Usage Monitor
    # Services which cannot be disabled
    #"WdNisSvc"
)

foreach ($service in $services) {
    Write-Output "Trying to disable $service"
    Get-Service -Name $service | Set-Service -StartupType Disabled
}

## This script removes unwanted Apps that come with Windows. If you  do not want
## to remove certain Apps comment out the corresponding lines below.
#
## Prevents Apps from re-installing
#$cdm = @(
#    "ContentDeliveryAllowed"
#    "FeatureManagementEnabled"
#    "OemPreInstalledAppsEnabled"
#    "PreInstalledAppsEnabled"
#    "PreInstalledAppsEverEnabled"
#    "SilentInstalledAppsEnabled"
#    "SubscribedContent-314559Enabled"
#    "SubscribedContent-338387Enabled"
#    "SubscribedContent-338388Enabled"
#    "SubscribedContent-338389Enabled"
#    "SubscribedContent-338393Enabled"
#    "SubscribedContentEnabled"
#    "SystemPaneSuggestionsEnabled"
#)
#
#New-FolderForced -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
#foreach ($key in $cdm) {
#    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" $key 0
#}
#
#New-FolderForced -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
#Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2
#
## Prevents "Suggested Applications" returning
#New-FolderForced -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
#Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

# Thank you Matthew Israelsson
Write-Output "Removing run hook for new users"
reg load "hku\Default" "C:\Users\Default\NTUSER.DAT"
reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f
reg unload "hku\Default"

Write-Output "Removing startmenu entry"
Remove-Item -Force -ErrorAction SilentlyContinue "$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"

Write-Output "Removing scheduled task"
Get-ScheduledTask -TaskPath '\' -TaskName 'OneDrive*' -ea SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

Write-Output "Restarting explorer"
Start-Process "explorer.exe"

Write-Output "Waiting for explorer to complete loading"
Start-Sleep 10

# This script removes all Start Menu Tiles from the .default user #

Set-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -Value '<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '  <LayoutOptions StartTileGroupCellWidth="6" />'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '  <DefaultLayoutOverride>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '    <StartLayoutCollection>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '      <defaultlayout:StartLayout GroupCellWidth="6" />'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '    </StartLayoutCollection>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '  </DefaultLayoutOverride>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '    <CustomTaskbarLayoutCollection>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '      <defaultlayout:TaskbarLayout>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '        <taskbar:TaskbarPinList>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '          <taskbar:UWA AppUserModelID="Microsoft.MicrosoftEdge_8wekyb3d8bbwe!MicrosoftEdge" />'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '          <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\File Explorer.lnk" />'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '        </taskbar:TaskbarPinList>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '      </defaultlayout:TaskbarLayout>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '    </CustomTaskbarLayoutCollection>'
Add-Content -Path 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml' -value '</LayoutModificationTemplate>'

$START_MENU_LAYOUT = @"
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
    <LayoutOptions StartTileGroupCellWidth="6" />
    <DefaultLayoutOverride>
        <StartLayoutCollection>
            <defaultlayout:StartLayout GroupCellWidth="6" />
        </StartLayoutCollection>
    </DefaultLayoutOverride>
</LayoutModificationTemplate>
"@

$layoutFile="C:\Windows\StartMenuLayout.xml"

#Delete layout file if it already exists
If(Test-Path $layoutFile)
{
    Remove-Item $layoutFile
}

#Creates the blank layout file
$START_MENU_LAYOUT | Out-File $layoutFile -Encoding ASCII

$regAliases = @("HKLM", "HKCU")

#Assign the start layout and force it to apply with "LockedStartLayout" at both the machine and user level
foreach ($regAlias in $regAliases){
    $basePath = $regAlias + ":\SOFTWARE\Policies\Microsoft\Windows"
    $keyPath = $basePath + "\Explorer"
    IF(!(Test-Path -Path $keyPath)) {
        New-Item -Path $basePath -Name "Explorer"
    }
    Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 1
    Set-ItemProperty -Path $keyPath -Name "StartLayoutFile" -Value $layoutFile
}

#Restart Explorer, open the start menu (necessary to load the new layout), and give it a few seconds to process
Stop-Process -name explorer
Start-Sleep -s 5
$wshell = New-Object -ComObject wscript.shell; $wshell.SendKeys('^{ESCAPE}')
Start-Sleep -s 5

#Enable the ability to pin items again by disabling "LockedStartLayout"
foreach ($regAlias in $regAliases){
    $basePath = $regAlias + ":\SOFTWARE\Policies\Microsoft\Windows"
    $keyPath = $basePath + "\Explorer"
    Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 0
}

#Restart Explorer and delete the layout file
Stop-Process -name explorer

# Uncomment the next line to make clean start menu default for all new users
Import-StartLayout -LayoutPath $layoutFile -MountPath $env:SystemDrive\
Remove-Item $layoutFile


# Prevents SYSPREP from freezing at "Getting Ready" on first boot                          #
# NOTE, DMWAPPUSHSERVICE is a Keyboard and Ink telemetry service, and potential keylogger. #
# It is recommended to disable this service in new builds, but SYSPREP will freeze/fail    #
# if the service is not running. If SYSPREP will be used, add a FirstBootCommand to your   #
# build to disable the service.                                                            #

#reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\dmwappushservice" /v "DelayedAutoStart" /f
#reg add "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\dmwappushservice" /v "DelayedAutoStart" /t REG_DWORD /d "1"
#reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\dmwappushservice" /v "Start" /f
#reg add "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\dmwappushservice" /v "Start" /t REG_DWORD /d "2"
# Add the line below to FirstBootCommand in answer file #
# reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "disabledmwappushservice" /t REG_SZ /d "sc config dmwappushservice start= disabled"


# Disable Privacy Settings Experience #
# Also disables all settings in Privacy Experience #

reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v "DisablePrivacyExperience" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v "DisablePrivacyExperience" /t REG_DWORD /d "1" /f
reg delete "HKEY_USERS\.DEFAULT\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v "HasAccepted" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Speech_OneCore" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Speech_OneCore\Settings" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v "HasAccepted" /t REG_DWORD /d "0" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v "HasAccepted" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Speech_OneCore" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Speech_OneCore\Settings" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v "HasAccepted" /t REG_DWORD /d "0" /f
reg delete "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v "Value" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v "Value" /t REG_SZ /d "Deny" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v "Value" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v "Value" /t REG_SZ /d "Deny" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Settings\FindMyDevice" /v "LocationSyncEnabled" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Settings\FindMyDevice" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Settings\FindMyDevice" /v "LocationSyncEnabled" /t REG_DWORD /d "0" /f
reg delete "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /v "ShowedToastAtLevel" /f
reg add "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics" /f
reg add "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /f
reg add "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /v "ShowedToastAtLevel" /t REG_DWORD /d "1" /f
reg delete "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /v "ShowedToastAtLevel" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /v "ShowedToastAtLevel" /t REG_DWORD /d "1" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d "1" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "MaxTelemetryAllowed" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "MaxTelemetryAllowed" /t REG_DWORD /d "1" /f
reg delete "HKEY_USERS\.DEFAULT\Software\Microsoft\Input\TIPC" /v "Enabled" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Input" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Input\TIPC" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Input\TIPC" /v "Enabled" /t REG_DWORD /d "0" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Input\TIPC" /v "Enabled" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Input" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Input\TIPC" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Input\TIPC" /v "Enabled" /t REG_DWORD /d "0" /f
reg delete "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Privacy" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d "0" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d "0" /f
reg delete "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /f
reg add "HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d "0" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d "0" /f


# Set Windows to Dark Mode #

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /v "AppsUseLightTheme" /t "REG_DWORD" /d "0" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /v "SystemUsesLightTheme" /t "REG_DWORD" /d "0" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t "REG_DWORD" /d "0" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t "REG_DWORD" /d "0" /f
reg add "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /f
reg add "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f
reg add "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t "REG_DWORD" /d "0" /f
reg add "HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t "REG_DWORD" /d "0" /f

##########
# Restart
##########
Write-Host
Write-Host "Press any key to restart your system..." -ForegroundColor Black -BackgroundColor White
#$key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#Write-Host "Restarting..."
#Restart-Computer   
}

#---End of functions---


#Decrapify
If ($NoLog) {
}Else  {
Start-Transcript $ENV:SYSTEMDRIVE\WindowsDCtranscript.txt
}
Write-Host "******Decrapifying Windows 10...******"
If ($AppsOnly) {
  RemoveApps
  ClearStartMenu
  Goodbye
}Elseif ($SettingsOnly) {
  DisableTasks
  DisableServices
  RegChange
  ClearStartMenu
  Goodbye
}Else {
RemoveApps
  DisableTasks
  DisableServices
  RegChange
  ClearStartMenu
  CBAdds
  Goodbye
}

If ($NoLog) {
}Else  {
Stop-Transcript
}