Configuration McBIC_Kids_Checkin_Initialization
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration -Name User
    Import-DscResource -ModuleName xSmbShare -Name xSmbShare -ModuleVersion '1.1.0.0'
    
    Node $AllNodes.NodeName
    {
    <# Set up the user accounts #>   
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
    <# End the user accounts #>

    <# Start Pull Configuration Section #>
        File PullFolder
        {
            Ensure = 'Present'
            Type = 'Directory'
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

# Create the list of computers this configuration will be applied to
$computers = @(
    'KIOSK-DEV',
    'KIOSK-NURSERY2'
)

# Add the computers to the configuration data
$computers | % { $configurationData.AllNodes += @{ NodeName = $_ } }

# Create the MOF files for the configuration
McBIC_Kids_Checkin_Initialization -OutputPath 'Deploy-Initial' -ConfigurationData $configurationData

# Create the checksums for the MOFs
New-DscChecksum -Path 'Deploy-Initial' -Force