Configuration McBIC_Kids_Checkin
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name Group
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name User
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name Registry
    Import-DscResource -ModuleName xSmbShare -Name xSmbShare -ModuleVersion '1.1.0.0'
    Import-DSCResource -ModuleName xTimeZone -Name xTimeZone -ModuleVersion '1.4.0.0'
    Import-DscResource -ModuleName CustomizeWindows10 -Name PowerPlan -ModuleVersion '0.0.0.4'
    Import-DscResource -ModuleName xWindowsUpdate -Name xMicrosoftUpdate -ModuleVersion '2.5.0.0'
    Import-DscResource -ModuleName xWindowsUpdate -Name xWindowsUpdateAgent -ModuleVersion '2.5.0.0'
    Import-DscResource -ModuleName Carbon -Name Carbon_ScheduledTask -ModuleVersion '2.2.0'
    Import-DscResource -ModuleName xComputerManagement -Name xScheduledTask -ModuleVersion '1.7.0.0'
    
    Node $AllNodes.NodeName
    {
    <# Set up the user accounts #>   
        User CheckIn
        {
            Description = 'Low privilege account ued for check ins.'
            Disabled = $false
            Ensure = 'Present'
            Password = $Node.CheckInPassword
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires = $true
            UserName = $Node.CheckInUserName
        }

        User McBICAdmin
        {
            Description = 'Admin account.'
            Disabled = $false
            Ensure = 'Present'
            Password = $Node.AdminPassword
            PasswordChangeNotAllowed = $false # Don't change this. Setting this to true will result in the configuration failing to apply
            PasswordNeverExpires = $true
            UserName = $Node.AdminUserName
        }

        Registry AutoLoginName
        {
            Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
            ValueName = 'DefaultUserName'
            Ensure = 'Present'
            Force = $true
            ValueData = 'Check In'
            ValueType = 'String'
            DependsOn = '[User]CheckIn'
        }

        Registry AutoLoginPassword
        {
            Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
            ValueName = 'DefaultPassword'
            Ensure = 'Present'
            Force = $true
            ValueData = 'mcbic'
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
    <# End the user accounts #>

    <# Start Pull Configuration Section #>
        File PullFolder
        {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = $node.PullDir
        }

        xSmbShare PullShare
        {
            Name = $Node.PullShareName
            Path = $Node.PullDir
            Ensure = 'Present'
            DependsOn = '[File]PullFolder'
        }

        LocalConfigurationManager
        {
            ConfigurationID = $Node.ConfigurationID
            ConfigurationMode='ApplyandAutoCorrect'
            ConfigurationModeFrequencyMins = 15
            RebootNodeIfNeeded = $True
            RefreshFrequencyMins = 30
            RefreshMode = 'PULL'
            DownloadManagerName = 'DSCFileDownloadManager'
            DownloadManagerCustomData = @{SourcePath = ('\\' + $Node.NodeName + '\' + $Node.PullShareName)}
        }
    <# End Pull Configuration Section #>

    <# Configure the time zone #>       
        xTimeZone TimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
        }
    <# End time zone configuration #>

    <# Configure the power plan #>       
        Registry CsEnabled
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
            DependsOn = '[Registry]CsEnabled'
            SleepAfterOnAC = '0'
            SleepAfterOnDC = '0'
            TurnOffDisplayAfterOnAC = '0'
            TurnOffDisplayAfterOnDC = '0'
        }
    <# End power plan configuration #>

    <# Branding #>
        File LogonScriptShortcut
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path ( Split-Path -Path $node.PullDir -Parent ) -ChildPath 'McBIC_Kids_CheckIn_Logon_Script.lnk' )
            DestinationPath = ( Join-Path -Path ([Environment]::GetFolderPath('CommonStartup')) -ChildPath 'McBIC_Kids_CheckIn_Logon_Script.lnk' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
        }

        Registry CheckinWallpaper
        {
            Key = 'HKEY_CURRENT_USER\Control Panel\Desktop'
            ValueName = 'Wallpaper'
            Ensure = 'Present'
            Force = $true
            ValueData = ( Join-Path -Path ( Split-Path -Path $node.PullDir -Parent ) -ChildPath '\Images\Background.png' )
            ValueType = 'String'
            PsDscRunAsCredential = $Node.CheckInPassword
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
            PsDscRunAsCredential = $Node.AdminPassword
            DependsOn = '[User]McBICAdmin'
        }
    <# End Branding #>

    <# User Experience #>
        Registry CheckinScreenSaver
        {
            Key = 'HKEY_CURRENT_USER\Control Panel\Desktop'
            ValueName = 'ScreenSaveActive'
            Ensure = 'Present'
            Force = $true
            ValueData = '0'
            ValueType = 'String'
            PsDscRunAsCredential = $Node.CheckInPassword
            DependsOn = '[User]CheckIn'
        }

        Registry ShowTaskBar
        {
            Key = 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
            ValueName = 'Settings'
            Ensure = 'Present'
            Force = $true
            ValueData = '30000000FEFFFFFF02020000030000007C0000003C0000000000000018060000400B0000540600009000000001000000'
            ValueType = 'Binary'
            PsDscRunAsCredential = $Node.CheckInPassword
            DependsOn = '[User]CheckIn'
        }
    <# End User Experience #>

    <# Windows Update #>
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
    <# End Windows Update #>

    # Create a scheduled task to sync changes from the GIT repository
        Carbon_ScheduledTask SyncRepository
        {
            Name = 'Retrieve Configuration Updates'
            DependsOn = '[File]PullFolder'
            Ensure = 'Present'
            TaskXml = $Node.SyncRepository
        }

    # Create a scheduled task to shut down the computer on Sunday at 12:30pm
        Carbon_ScheduledTask WeeklyShutDown
        {
            Name = 'Weekly ShutDown'
            Ensure = 'Present'
            TaskXml = $Node.WeeklyShutDown
        }

    <# Remove the old stuff #>
        file RemoveCheckInShortcutCheckInStartup
        {
            Ensure = 'Absent'
            Type = 'File'
            DestinationPath = 'C:\Users\Check In\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Check In.lnk'
            Force = $true
            DependsOn = '[User]CheckIn'
        }

        file RemoveCheckInShortcutCheckInDesktop
        {
            Ensure = 'Absent'
            Type = 'File'
            DestinationPath = 'C:\Users\Check In\Desktop\Check In.lnk'
            Force = $true
            DependsOn = '[User]CheckIn'
        }

        file RemoveCheckInShortcutAdminDesktop
        {
            Ensure = 'Absent'
            Type = 'File'
            DestinationPath = 'C:\Users\Check In\Desktop\Check In.lnk'
            Force = $true
            DependsOn = '[User]McBICAdmin'
        }

        file RemoveAutoLoginOnAdminDesktop
        {
            Ensure = 'Absent'
            Type = 'File'
            DestinationPath = 'C:\Users\Check In\Desktop\Auto Login On.lnk'
            Force = $true
            DependsOn = '[User]McBICAdmin'
        }

        file RemoveAutoLoginOffAdminDesktop
        {
            Ensure = 'Absent'
            Type = 'File'
            DestinationPath = 'C:\Users\Check In\Desktop\Auto Login Off.lnk'
            Force = $true
            DependsOn = '[User]McBICAdmin'
        }

        file RemoveMBK_TB_Setup
        {
            Ensure = 'Absent'
            Type = 'Directory'
            DestinationPath = 'C:\MBK_TB_Setup'
            Force = $true
        }
    <# End Remove the old stuff #>
    }
}

# Load the global configurations
[xml]$xmlConfig = Get-Content -Path ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath 'MOF_Creation_Parameters.xml' )

# Set up the configuration data
$configurationData = 
@{
    AllNodes = 
    @(
        @{
            NodeName = '*'
            PSDscAllowPlainTextPassword = $true
            AdminUserName = $xmlConfig.mofCreationParameters.AdminUser.UserName
            AdminPassword = New-Object System.Management.Automation.PSCredential($xmlConfig.mofCreationParameters.AdminUser.UserName,(ConvertTo-SecureString -String $xmlConfig.mofCreationParameters.AdminUser.Password -AsPlainText -Force))
            CheckInUserName = $xmlConfig.mofCreationParameters.CheckInUser.UserName
            CheckInPassword = New-Object System.Management.Automation.PSCredential($xmlConfig.mofCreationParameters.CheckInUser.UserName,(ConvertTo-SecureString -String $xmlConfig.mofCreationParameters.CheckInUser.Password -AsPlainText -Force))
            ConfigurationID = $xmlConfig.mofCreationParameters.ConfigId.ConfigId
            GitRepoDir = $xmlConfig.mofCreationParameters.GitRepoDir.GitRepoDir
            InitializationPushSource = $xmlConfig.mofCreationParameters.InitializationPushSource.InitializationPushSource
            PullDir = $xmlConfig.mofCreationParameters.PullDir.PullDir
            PullShareName = $xmlConfig.mofCreationParameters.PullShareName.PullShareName
            SyncRepository = ( Get-Content -Path ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath 'ScheduledTasks\Retrieve_Configuration_Updates.xml' ) ) -join ''
            WeeklyShutDown = ( Get-Content -Path ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath 'ScheduledTasks\WeeklyShutDown.xml' ) ) -join ''
        }
    )
}

# Add the computers to the configuration data
$xmlConfig.mofCreationParameters.ConfigId.ConfigId | % { $configurationData.AllNodes += @{ NodeName = $_ } }

# Create the MOF files for the configuration
McBIC_Kids_Checkin -OutputPath ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath ( Split-Path -Path $xmlConfig.mofCreationParameters.PullDir.PullDir -Leaf ) ) -ConfigurationData $configurationData

# Copy the resources to the deployment pull folder
Copy-Item -Path ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath 'Resources\*' ) -Destination ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath ( Split-Path -Path $xmlConfig.mofCreationParameters.PullDir.PullDir -Leaf ) )

# Create the checksums for the MOFs
New-DscChecksum -Path ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath ( Split-Path -Path $xmlConfig.mofCreationParameters.PullDir.PullDir -Leaf ) ) -Force