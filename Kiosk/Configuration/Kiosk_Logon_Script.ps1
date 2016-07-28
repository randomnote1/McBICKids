# Load the global configurations
[xml]$xmlConfig = Get-Content -Path ( Join-Path -Path ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent ) -ChildPath 'MOF_Creation_Parameters.xml' )

# Set the desktop wallpaper
Write-Host 'Setting the desktop wallpaper...'
$wallpaperKey = 'HKCU:\Control Panel\Desktop'
$wallpaperValue = ( Join-Path -Path ( Split-Path -Path $xmlConfig.mofCreationParameters.PullDir.PullDir -Parent ) -ChildPath '\Images\Background.png' )
if ( ( Get-ItemProperty -Path $wallpaperKey -Name Wallpaper ).Wallpaper -ne $wallpaperValue )
{
    Set-ItemProperty -Path $wallpaperKey -Name Wallpaper -Value $wallpaperValue
}

switch ( $env:USERNAME )
{
 
    'check in'
    {
        #[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        
        # Create a new IE object
        $ie = New-Object -ComObject InternetExplorer.Application
        $ie.Visible = $false

        # Navigate to lambslist
        $checkinURL = 'https://checkin.lambslist.com/families/self_checkin'
        $ie.Navigate($checkinURL)

        # Wait for the page to load
        while ( $ie.Busy ) { Start-Sleep -Seconds 1 }
        
        # Sleep for no reason at all
        Start-Sleep -Seconds 5

        # Get the page
        $doc = $ie.Document

        # If we need to log into the page
        if ( $doc.getElementById('login').Value )
        {
            # Enter the username
            $doc.getElementById('login').Value = 'test'

            # Enter the password
            $doc.getElementById('password').Value = 'test'

            # Click "Log in"
            $doc.getElementsByName('commit').item(0).click()

            # Wait for the page to load
            while ( $ie.Busy ) { Start-Sleep -Seconds 1 }
        }

        # Navigate to the self-service kiosk
        $ie.Navigate($checkinURL)

        # Wait for the page to load
        while ( $ie.Busy ) { Start-Sleep -Seconds 1 }

        # Set it to kiosk mode
        $ie.FullScreen = $true

        # make the page visible
        $ie.Visible = $true

        # Bring the IE window to the front
        [void] [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
        [Microsoft.VisualBasic.Interaction]::AppActivate((Get-Process | ? { $_.MainWindowHandle -eq $ie.HWND } | select -ExpandProperty Id))
    }
    else
    {
        Write-Host 'Unable to connect to Lambs List. Make sure the computer is connected to the internet and try again.' -ForegroundColor Red
    }
}

# Pause at the end
Start-Sleep -Seconds 5