Configuration McBIC_Checkin_Kiosk
{
    Import-DscResource -ModuleName CustomizeWindows10 -ModuleVersion 0.0.0.7
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement -ModuleVersion 2.1.0.0
    Import-DscResource -ModuleName xSmbShare -ModuleVersion 2.0.0.0
    Import-DSCResource -ModuleName xTimeZone -ModuleVersion 1.6.0.0

    Node $AllNodes.NodeName
    {
        #region Pull Server Configuration
            LocalConfigurationManager
            {
                ActionAfterReboot = 'ContinueConfiguration'
                AllowModuleOverwrite = $true
                CertificateID = ''
                ConfigurationID = 'e2005ca8-6dd6-4939-a4c0-dbb7d06e7b4d' # ConfigurationID required for a known bug
                ConfigurationMode='ApplyandAutoCorrect'
                ConfigurationModeFrequencyMins = 15
                DebugMode = $false
                RebootNodeIfNeeded = $true
                RefreshFrequencyMins = 30
                RefreshMode = 'PULL'
                DownloadManagerName = 'DSCFileDownloadManager'
                DownloadManagerCustomData = @{ SourcePath = "\\$($Node.NodeName)\$($Node.PullShareName)" }
            }

            File PullFolder
            {
                Ensure = 'Present'
                Type = 'Directory'
                DestinationPath = $Node.PullSharePath
            }

            xSmbShare PullShare
            {
                Name = $Node.PullShareName
                Path = $Node.PullSharePath
                Ensure = 'Present'
                DependsOn = '[File]PullFolder'
            }
        #endregion Pull Server Configuration
        
        #region User Accounts
            User McBICAdmin
            {
                Description = 'Admin account.'
                Disabled = $false
                Ensure = 'Present'
                Password = $Node.AdminCredential
                PasswordChangeNotAllowed = $false # Don't change this. Setting this to true will result in the configuration failing to apply
                PasswordNeverExpires = $true
                UserName = $Node.AdminUserName
            }

            User CheckIn
            {
                Description = 'Low privilege account used for check ins.'
                Disabled = $false
                Ensure = 'Present'
                Password = $Node.CheckInCredential
                PasswordChangeNotAllowed = $true
                PasswordNeverExpires = $true
                UserName = $Node.CheckInUserName
            }
        #endregion User Accounts

        #region Automatic Login
            Registry AutoLoginName
            {
                Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
                ValueName = 'DefaultUserName'
                Ensure = 'Present'
                Force = $true
                ValueData = $Node.CheckInUserName
                ValueType = 'String'
                DependsOn = '[User]CheckIn'
            }

            Registry AutoLoginPassword
            {
                Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
                ValueName = 'DefaultPassword'
                Ensure = 'Present'
                Force = $true
                ValueData = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Node.CheckInCredential.Password))
                ValueType = 'String'
                DependsOn = '[Registry]AutoLoginName'
            }
            
            Registry AutoLogin
            {
                Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
                ValueName = 'AutoAdminLogon'
                Ensure = 'Present'
                Force = $true
                ValueData = '1'
                ValueType = 'Dword'
                DependsOn = '[Registry]AutoLoginPassword'
            }
        #endregion Automatic Login

        #region Time Settings
            xTimeZone TimeZone
            {
                IsSingleInstance = 'Yes'
                TimeZone = 'Eastern Standard Time'
            }

            ### ToDo: Configure a time source
        #endregion Time Settings

        #region Power Settings
            Registry ConnectedStandbyModeDisabled
            {
                Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power'
                ValueName = 'CsEnabled'
                Ensure = 'Present'
                Force = $true
                ValueData = 0
                ValueType = 'Dword'
            }
            
            PowerPlan PowerPlan
            {
                ActivePowerPlan = 'Balanced'
                DependsOn = '[Registry]ConnectedStandbyModeDisabled'
                SleepAfterOnAC = '0'
                SleepAfterOnDC = '0'
                TurnOffDisplayAfterOnAC = '0'
                TurnOffDisplayAfterOnDC = '0'
                HibernateAfterOnAC = '0'
                HibernateAfterOnDC = '0'
            }
        #endregion Power Settings

        #region Branding
            Registry CheckinWallpaper
            {
                Key = 'HKEY_CURRENT_USER\Control Panel\Desktop'
                ValueName = 'Wallpaper'
                Ensure = 'Present'
                Force = $true
                ValueData = $Node.BackgroundImagePath
                ValueType = 'String'
                PsDscRunAsCredential = $Node.CheckInCredential
                DependsOn = '[User]CheckIn'
            }

            Registry AdminBackground
            {
                Key = 'HKEY_CURRENT_USER\Control Panel\Colors'
                ValueName = 'Background'
                Ensure = 'Present'
                Force = $true
                ValueData = '0 0 0'
                ValueType = 'String'
                PsDscRunAsCredential = $Node.AdminCredential
                DependsOn = '[User]McBICAdmin'
            }
        #endregion Branding

        #region User Experience
            Registry DisableScreenSaverForCheckInUser
            {
                Key = 'HKEY_CURRENT_USER\Control Panel\Desktop'
                ValueName = 'ScreenSaveActive'
                Ensure = 'Present'
                Force = $true
                ValueData = '0'
                ValueType = 'String'
                PsDscRunAsCredential = $Node.CheckInCredential
                DependsOn = '[User]CheckIn'
            }

            Registry InternetExplorerZoom
            {
                Key = 'HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\Zoom'
                ValueName = 'ZoomFactor'
                Ensure = 'Present'
                Force = $true
                ValueData = $Node.InternetExplorerZoomLevel * 1000
                ValueType = 'Dword'
                PsDscRunAsCredential = $Node.CheckInCredential
                DependsOn = '[User]CheckIn'
            }
        #endregion User Experience

        #region Windows Update
            xMicrosoftUpdate MicrosoftUpdate
            {
                Ensure = 'Present'
            }

            xWindowsUpdateAgent WindowsUpdateAgent
            {
                IsSingleInstance = 'Yes'
                Source = 'MicrosoftUpdate'
                Category = 'Important','Optional','Security'
                Notifications = 'Disabled'
            }
        #endregion Windows Update

        #region Login Script Shortcuts
            File LogonScriptDesktopShortcut
            {
                Ensure = 'Present'
                Type = 'File'
                SourcePath = ( Join-Path -Path ( Split-Path -Path $node.PullSharePath -Parent ) -ChildPath 'LaunchKiosk.lnk' )
                DestinationPath = ( Join-Path -Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) -ChildPath 'LaunchKiosk.lnk' )
                CheckSum = 'SHA-256'
                Force = $true
                MatchSource = $true
            }

            File LogonScriptStartupShortcut
            {
                Ensure = 'Present'
                Type = 'File'
                SourcePath = ( Join-Path -Path ( Split-Path -Path $node.PullSharePath -Parent ) -ChildPath 'LaunchKiosk.lnk' )
                DestinationPath = ( Join-Path -Path ([Environment]::GetFolderPath('CommonStartup')) -ChildPath 'LaunchKiosk.lnk' )
                CheckSum = 'SHA-256'
                Force = $true
                MatchSource = $true
            }
        #endregion Login Script Shortcuts

        #region Scheduled Tasks
            xScheduledTask SyncRepository
            {
                ActionArguments = 'pull "https://github.com/randomnote1/McBICKids.git"'
                ActionExecutable = 'C:\Program Files\Git\cmd\git.exe'
                ActionWorkingPath = 'C:\Repos\McBICKids'
                AllowStartIfOnBatteries = $true
                DaysInterval = 1
                DependsOn = '[File]PullFolder'
                DisallowHardTerminate = $false
                DisallowDemandStart = $false
                DontStopIfGoingOnBatteries = $true
                Enable = $true
                Ensure = 'Present'
                Hidden = $false
                MultipleInstances = 'IgnoreNew'
                RepeatInterval = '00:15:00'
                RepetitionDuration = 'Indefinitely'
                RunOnlyIfIdle = $false
                RunOnlyIfNetworkAvailable = $true
                ScheduleType = 'Daily'
                StartWhenAvailable = $true
                TaskName = 'Retrieve Configuration Updates'
            }

            xScheduledTask NightlyShutdown
            {
                ActionArguments = '/s /t 300 /d p:0:0 /c "Nightly ShutDown"'
                ActionExecutable = 'C:\Windows\System32\shutdown.exe'
                ActionWorkingPath = 'C:\Repos\McBICKids'
                AllowStartIfOnBatteries = $true
                DaysOfWeek = 'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'
                DisallowHardTerminate = $false
                DisallowDemandStart = $false
                DontStopIfGoingOnBatteries = $true
                Enable = $true
                Ensure = 'Present'
                Hidden = $false
                MultipleInstances = 'IgnoreNew'
                RunOnlyIfIdle = $false
                RunOnlyIfNetworkAvailable = $false
                ScheduleType = 'Weekly'
                StartTime = '20:25:00'
                StartWhenAvailable = $false
                TaskName = 'Nightly Shutdown'
            }

            xScheduledTask WeeklyShutdown
            {
                ActionArguments = '/s /t 300 /d p:0:0 /c "Nightly ShutDown"'
                ActionExecutable = 'C:\Windows\System32\shutdown.exe'
                ActionWorkingPath = 'C:\Repos\McBICKids'
                AllowStartIfOnBatteries = $true
                DaysOfWeek = 'Sunday'
                DisallowHardTerminate = $false
                DisallowDemandStart = $false
                DontStopIfGoingOnBatteries = $true
                Enable = $true
                Ensure = 'Present'
                Hidden = $false
                MultipleInstances = 'IgnoreNew'
                RunOnlyIfIdle = $false
                RunOnlyIfNetworkAvailable = $false
                ScheduleType = 'Weekly'
                StartTime = '12:10:00'
                StartWhenAvailable = $false
                TaskName = 'Weekly Shutdown'
            }
        #endregion Scheduled Tasks
    }
}