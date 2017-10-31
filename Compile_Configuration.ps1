param
(
    [Parameter()]
    [System.String]
    $EnvironmentName = 'McBIC_Checkin_Kiosk'
)

# Ensure we're running in the root directory of the repo
Push-Location
Set-Location -Path $PSScriptRoot

# Build the path to the configurations directory
$configurationsDirectory = Join-Path -Path $PSScriptRoot -ChildPath Configurations
$environmentsDirectory = Join-Path -Path $PSScriptRoot -ChildPath Environments

# Get the Environment file
$environmentFile = Join-Path -Path $environmentsDirectory -ChildPath "$EnvironmentName.ps1"

if ( -not ( Test-Path -Path $environmentFile ) )
{
    [array]$allEnvironmentFiles = Get-ChildItem -Path $environmentsDirectory

    # Allow the user to select the environment file
    $selectedEnvironment = $allEnvironmentFiles | Select-Object -ExpandProperty BaseName | Out-GridView -Title 'Select the desired environment' -OutputMode Single
    
    $environmentFile = Get-ChildItem -Path $environmentsDirectory | Where-Object -FilterScript { $_.BaseName -eq $selectedEnvironment } | Select-Object -ExpandProperty FullName

    try
    {
        Test-Path -Path $environmentFile -ErrorAction Stop
    }
    catch
    {
        throw 'No environment file specified.'
    }
}

# Retrieve the settings from the environment file
. $environmentFile

# Get the Configuration file
$configurationFile = Join-Path -Path $configurationsDirectory -ChildPath 'Checkin_Kiosk.ps1'
. $configurationFile
Checkin_Kiosk -ConfigurationData $ConfigData -Verbose

# Change the directory back to where we started
Pop-Location
