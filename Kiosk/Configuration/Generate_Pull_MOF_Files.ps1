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
            Recurse = $false
            DestinationPath = $node.PullSource
        }

        File ConfigMetaMof
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath (  $node.ConfigurationID + '.meta.mof' ) )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath ( $node.ConfigurationID + '.meta.mof' ) )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]PullFolder'
        }

        File ConfigMetaMofChecksum
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath =  ( Join-Path -Path $node.MofSource -ChildPath ( $node.ConfigurationID + '.meta.mof.checksum' ) )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath ( $node.ConfigurationID + '.meta.mof.checksum' ) )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]PullFolder'
        }
        
        File ConfigMof
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath ( $node.ConfigurationID + '.mof' ) )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath ( $node.ConfigurationID + '.mof' ) )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]PullFolder'
        }

        File ConfigMofChecksum
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath ( $node.ConfigurationID + '.mof.checksum' ) )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath ( $node.ConfigurationID + '.mof.checksum' ) )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true 
            DependsOn = '[File]PullFolder'
        }

        xSmbShare PullShare
        {
            Name = 'DSCPull'
            Path = $node.PullSource
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
            DownloadManagerCustomData = @{SourcePath = ('\\' + $Node.NodeName + '\DSCPull')}
        }

    <# End Pull Configuration Section #>

    <# Configure the time zone #>       
        File TimeZoneResource
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath 'Resources\xTimeZone_1.4.0.0.zip' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'xTimeZone_1.4.0.0.zip' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
        }

        File TimeZoneResourceChecksum
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath 'Resources\xTimeZone_1.4.0.0.zip.checksum' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'xTimeZone_1.4.0.0.zip.checksum' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]TimeZoneResource'
        }
        
        xTimeZone TimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone = 'Eastern Standard Time'
            DependsOn = '[File]TimeZoneResourceChecksum'
        }
    <# End time zone configuration #>

    <# Configure the power plan #>       
        File PowerPlanResource
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath 'Resources\cPowerPlan_1.0.0.0.zip' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'cPowerPlan_1.0.0.0.zip' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
        }

        File PowerPlanResourceChecksum
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath 'Resources\cPowerPlan_1.0.0.0.zip.checksum' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'cPowerPlan_1.0.0.0.zip.checksum' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]PowerPlanResource'
        }
        
        cPowerPlan PowerPlan
        {
            IsSingleInstance = 'Yes'
            PowerPlan = 'High Performance'
            DependsOn = '[File]PowerPlanResourceChecksum'
        }
    <# End power plan configuration #>

    <# Branding #>
        File ImagesFolder
        {
            Ensure = 'Present'
            Type = 'Directory'
            Recurse = $false
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'Images' )
        }

        File BackgroundImage
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath 'Images\Background.png' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath '\Images\Background.png' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]ImagesFolder'
        }

        File LogonScript
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $Node.MofSource -ChildPath 'McBIC_Kids_CheckIn_Login_Script.ps1' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'McBIC_Kids_CheckIn_Login_Script.ps1' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]ImagesFolder'
        }

        File LogonScriptShortcut
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $Node.MofSource -ChildPath 'McBIC_Kids_CheckIn_Login_Script.lnk' )
            DestinationPath = ( Join-Path -Path ([Environment]::GetFolderPath('CommonStartup')) -ChildPath 'McBIC_Kids_CheckIn_Login_Script.lnk' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]LogonScript'
        }
    <# End Branding #>

    <# Windows Update #>
        File WindowsUpdateResource
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath 'Resources\xWindowsUpdate_2.5.0.0.zip' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'xWindowsUpdate_2.5.0.0.zip' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]PullFolder'
        }

        File WindowsUpdateResourceChecksum
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = ( Join-Path -Path $node.MofSource -ChildPath 'Resources\xWindowsUpdate_2.5.0.0.zip.checksum' )
            DestinationPath = ( Join-Path -Path $node.PullSource -ChildPath 'xWindowsUpdate_2.5.0.0.zip.checksum' )
            CheckSum = 'SHA-256'
            Force = $true
            MatchSource = $true
            DependsOn = '[File]WindowsUpdateResource'
        }

        xMicrosoftUpdate MicrosoftUpdate
        {
            Ensure = 'Present'
            DependsOn = '[File]WindowsUpdateResourceChecksum'
        }

        xWindowsUpdateAgent WindowsUpdateAgent
        {
            IsSingleInstance = 'Yes'
            Source = 'MicrosoftUpdate'
            Category = 'Important','Optional','Security'
            DependsOn = '[File]WindowsUpdateResourceChecksum'
            Notifications = 'Disabled'
        }
    <# End Windows Update #>
    }
}

# Configure the Check In username and password
$checkinPassword = ConvertTo-SecureString -String 'mcbic' -AsPlainText -Force
$checkinUsername = 'Check In'
$checkinCred = New-Object System.Management.Automation.PSCredential($checkinUsername,$checkinPassword)

# Configure the Admin username and password
$adminPassword = ConvertTo-SecureString -String '1050SYorkSt' -AsPlainText -Force
$adminUserName = 'McBIC Admin'
$adminCred = New-Object System.Management.Automation.PSCredential($adminUserName,$adminPassword)

# Specify the configuration id to use for all of the nodes
$configID = '24145e72-50a3-4c11-b8e2-85c95e886152'

# Set up the configuration data
$configurationData = 
@{
    AllNodes = 
    @(
        @{
            NodeName = '*'
            PSDscAllowPlainTextPassword = $true
            CheckInUserName = $checkinUsername
            CheckInPassword = $checkinCred
            AdminUserName = $adminUserName
            AdminPassword = $adminCred
            ConfigurationID = $configID
            MofSource = ( Join-Path -Path ( Join-Path -Path 'C:\Users\McBIC Admin\OneDrive' -ChildPath ( Get-Item -Path (Get-Location).Path ).Name ) -ChildPath 'McBIC_Kids_Checkin' )
            PullSource = 'C:\DSCPull'
        }
    )
}

# Add the computers to the configuration data
$configID | % { $configurationData.AllNodes += @{ NodeName = $_ } }

# Create the MOF files for the configurations
McBIC_Kids_Checkin -OutputPath 'Deploy-Pull' -ConfigurationData $configurationData
McBIC_Kids_Checkin_Initialization -OutputPath 'Deploy-Initial' -ConfigurationData $configurationDataInitial

# Create the checksums for the MOFs
New-DscChecksum -Path 'Deploy-Pull' -Force

# Copy the resources to the deployment pull folder
Copy-Item -Path 'Resources\*' -Destination 'Deploy-Pull\.'