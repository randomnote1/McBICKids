Configuration McBIC_Kids_Checkin
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name Group
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name User
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name Registry
    Import-DscResource -ModuleName xSmbShare -Name xSmbShare -ModuleVersion '1.1.0.0'
    Import-DSCResource -ModuleName xTimeZone -Name xTimeZone -ModuleVersion '1.4.0.0'
    Import-DscResource -ModuleName cPowerPlan -Name cPowerPlan -ModuleVersion '1.0.0.0'
    Import-DscResource -ModuleName xWindowsUpdate -Name xMicrosoftUpdate -ModuleVersion '2.5.0.0'
    Import-DscResource -ModuleName xWindowsUpdate -Name xWindowsUpdateAgent -ModuleVersion '2.5.0.0'
    Import-DSCResource -ModuleName xComputerManagement -Name xScheduledTask -ModuleVersion '1.7.0.0'
    
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
        cPowerPlan PowerPlan
        {
            IsSingleInstance = 'Yes'
            PowerPlan = 'High Performance'
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
    <# End Branding #>

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
        xScheduledTask SyncRepository
        {
            TaskName = 'Retrieve Configuration Updates'
            ActionWorkingPath = 'C:\Repos\McBICKids'
            ActionExecutable = 'C:\Program Files\Git\cmd\git.exe'
            ActionArguments = ' pull "https://github.com/randomnote1/McBICKids.git"'
            ScheduleType = 'Minutes'
            RepeatInterval = 15
            StartTime = '12:00 AM'
            Ensure = 'Present'
            Enable = $true
            DependsOn = '[File]PullFolder'
        }
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