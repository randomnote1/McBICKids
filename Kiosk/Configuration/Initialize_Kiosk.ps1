<#
# Run these commands manually prior to running this script
$initializationScript = Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads\Initialize_Kiosk.ps1'
(New-Object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/randomnote1/McBICKids/master/Kiosk/Configuration/Initialize_Kiosk.ps1',$initializationScript)
Set-ExecutionPolicy RemoteSigned
& $initializationScript
#>

# Define the path to the pull folder
$pullFolder = 'C:\DSCPull\McBICKids'

# Make sure the computer is named properly
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
Write-Host 'Checking the computer name...' -ForegroundColor Cyan
if ( [System.Windows.Forms.MessageBox]::Show(('The computer name is "' + $env:COMPUTERNAME + '". Would you like to change it?'),'Change computer name?',4) -eq 'YES' )
{
    # Rename the computer
    Rename-Computer -ComputerName $env:COMPUTERNAME -NewName ( Read-Host -Prompt 'Enter the new computer name' )

    # Give the user some instructions
    Write-Host 'After the computer is restarted, run this script again.'

    # Restart the computer
    Restart-Computer -Force -Confirm
    
    # If for some reason the computer is not restarted, exit the script
    Exit
}

# Make sure the network connection is set to private
Write-Host 'Setting the network profile to private...' -ForegroundColor Cyan
Get-NetConnectionProfile | % { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory 'Private' }

# enable winrm
Write-Host 'Configuring WINRM...' -ForegroundColor Cyan
[array]'y'*2 | winrm quickconfig

# Pause a bit
Start-Sleep -Seconds 10

# Add the local computer to the trusted hosts
#Write-Host 'Configuring the WINRM trusted hosts...' -ForegroundColor Cyan
#winrm set winrm/config/client ( '@{TrustedHosts=' + $env:COMPUTERNAME + '}' )
#winrm set winrm/config/client @{'TrustedHosts' = $env:COMPUTERNAME }

# Check if GIT is installed
try { git --verionsion | Out-Null }
catch
{
    # Download GIT
    $client = New-Object System.Net.WebClient
    $downloadURL = 'https://github.com/git-for-windows/git/releases/download/v2.9.2.windows.1/Git-2.9.2-32-bit.exe'
    $downloadPath = Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads\git.exe'
    $client.DownloadFile($downloadURL,$downloadPath)

    # Install GIT
    & $downloadPath /SILENT /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"

    $gitNotInstalled = $true
    while ( $gitNotInstalled )
    {
        # Update the path
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        try
        {
            git --version
            $gitNotInstalled = $false
        } 
        catch { start-sleep -Seconds 30 }
    }
}

# Clone the source
git clone 'https://github.com/randomnote1/McBICKids.git' $pullFolder

# Install the package provider
Write-Host 'Install the NuGet package provider...' -ForegroundColor Cyan
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop

# Trust the 'PSGallery' repository
Write-Host 'Add the PSGallery to the trusted repositories...' -ForegroundColor Cyan
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop

# Install the xSmbShare resource
Write-Host 'Install the xSmbShare module...' -ForegroundColor Cyan
Install-Module -Name xSmbShare -ErrorAction Stop

# Define the MOF folder
Write-Host 'Performing the initial push configuration...' -ForegroundColor Cyan
$mofFolder = ( Join-Path -Path $pullFolder -ChildPath '\Kiosk\Configuration\Deploy-Initial' )

# Set the configuration
Start-DscConfiguration -ComputerName $env:COMPUTERNAME -Path $mofFolder -Wait -Verbose -Force

# Determine where the mof files will be stored
Write-Host 'Waiting for the configuration to complete...' -ForegroundColor Cyan
$mofLocation = ( Get-DscConfiguration | ? { $_.ResourceID -eq '[File]PullFolder' } ).DestinationPath

# Snooze while the path is created
while ( -not ( Test-Path -Path $mofLocation ) ) { Start-Sleep -Seconds 5 }

# Set the local configuration manager to pull mode
Write-Host 'Configure the LCM to PULL mode...' -ForegroundColor Cyan
Set-DscLocalConfigurationManager -Path $mofFolder -ComputerName $env:COMPUTERNAME -Force