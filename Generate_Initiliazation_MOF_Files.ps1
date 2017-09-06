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
            DestinationPath = $Node.PullDir
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
            ConfigurationID = $xmlConfig.mofCreationParameters.ConfigId.ConfigId
            GitRepoDir = $xmlConfig.mofCreationParameters.GitRepoDir.GitRepoDir
            InitializationPushSource = $xmlConfig.mofCreationParameters.InitializationPushSource.InitializationPushSource
            PullDir = $xmlConfig.mofCreationParameters.PullDir.PullDir
            PullShareName = $xmlConfig.mofCreationParameters.PullShareName.PullShareName
        }
    )
}

# Add the computers to the configuration data
$xmlConfig.mofCreationParameters.Computers.Computer | % { $configurationData.AllNodes += @{ NodeName = $_.Name } }

# Create the MOF files for the configuration
McBIC_Kids_Checkin_Initialization -OutputPath ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath ( Split-Path -Path $xmlConfig.mofCreationParameters.InitializationPushSource.InitializationPushSource -Leaf ) ) -ConfigurationData $configurationData

# Create the checksums for the MOFs
New-DscChecksum -Path ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath ( Split-Path -Path $xmlConfig.mofCreationParameters.InitializationPushSource.InitializationPushSource -Leaf ) ) -Force