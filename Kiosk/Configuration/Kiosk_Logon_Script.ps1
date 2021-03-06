Begin
{
    $loginName = 'djreist@gmail.com'
    $loginPassword = 'mcbic1050'

    # Get the original error action preference
    $originalErrorActionPreference = $ErrorActionPreference
}

Process
{
    #if ( $env:USERNAME -eq 'check in' )
    if ( $env:USERNAME )
    {
        $ie = New-Object -ComObject InternetExplorer.Application
        
        # Navigate to Planning Center Check-Ins
        $checkinURL = 'https://check-ins.planningcenteronline.com/station'
        $ie.Navigate($checkinURL)

        # Wait for the page to load
        do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )

        # Get the head of the page
        # Must do it this way because the document element properties are not instantiated when Office is not installed
        $head = $ie.Document.getElementsByTagName('head') | Select-Object -ExpandProperty innerHTML

        # If we need to log into the page
        if ( $head -match '^<title>Login - Accounts</title>' )
        {        
            # Enter the username
            $ie.Document.getElementById('email').Value = $loginName

            # Enter the password
            $ie.Document.getElementById('password').Value = $loginPassword

            # Click "Log in"
            $ie.Document.getElementsByName('commit').item(0).click()

            # Wait for the page to load
            do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )

            # If the account selection screen is displayed
            if ( $ie.Document.getElementsByTagName('a') | Where-Object -FilterScript { ( $_.href -match 'user_id=28987447' ) -and ( $_.textContent -eq 'Log in' ) } )
            {
                $userLoginButton = $ie.Document.getElementsByTagName('a') | Where-Object -FilterScript { ( $_.href -match 'user_id=28987447' ) -and ( $_.textContent -eq 'Log in' ) }
                $userLoginButton.click()

                # Wait for the page to load
                do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )
            }
        }

        # If the station isn't registered
        if ( -not [string]::IsNullOrEmpty( $ie.Document.getElementById('station_name') ) )
        {
            # Enter the name of the kiosk into the station name text box
            $i = 0
            do
            {
                $stationName = $ie.Document.getElementById('station_name')
                $stationName.Value = "$($env:COMPUTERNAME) "
                $i++

                if ( $i -eq 3 )
                {
                    throw 'Could not locate the station name field.'
                }
            }
            while ( $stationName.id -ne 'station_name' )
        }

        # The automated registration process is not working right now
        # This is because the REACT.js framework is being used and I am
        # unable to interact properly with the DOM. If I can figure out 
        # to interact with REACT.js through automation, this will be resolved.
        <#
            # This is a workaround for how REACT.js handles input into a text box. Really weird stuff. Thanks Facebook!
            # The text entered into the textbox is actually never part of the HTML DOM. Even the real onChange event is obfuscated
            # behind sever layers of javascript, jQuery, and REACT classes. I have not yet figured out how to trigger the event
            # in REACT or to call the method it calls. Either would be fine!
            [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
            [Windows.Forms.MessageBox]::Show('Delete the space from the end of the computername and then click "OK" on this messagebox.', 'Automation Issue', [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            
            # Get the button to create the station and click it!
            $createMyStationButton = $ie.Document.getElementsByTagName('button') | Where-Object -FilterScript { $_.textContent -eq 'Create my station' }
            $createMyStationButton.click()

            # Wait for the page to load
            do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )

            # Get the station type dropdown and set it to 'self'
            $stationType = $ie.Document.getElementById('station_type')
            $stationType.childNodes | Where-Object -FilterScript { $_.Text -eq 'Self' } | ForEach-Object -Process { $_.selected = $true }

            # Set the station's theme
            $theme = $ie.Document.getElementsByTagName('select') | Where-Object -FilterScript { $_.name -eq 'station[theme_id]' }
            $theme.childNodes | Where-Object -FilterScript { $_.Text -eq 'McBIC Blue' } | ForEach-Object -Process { $_.selected = $true }

            # Click Save and Continue
            $saveAndContinue = $ie.Document.getElementsByTagName('button') | Where-Object -FilterScript { $_.textContent -eq 'Save and Continue' }
            $saveAndContinue.click()

            # Wait for the page to load
            do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )

            # Print to this station
            $printTo = $ie.Document.getElementsByTagName('select') | Where-Object -FilterScript { $_.name -eq 'station[print_station_id]' }
            $printTo.childNodes | Where-Object -FilterScript { $_.Text -eq 'This station' } | ForEach-Object -Process { $_.selected = $true }        

            # Click Save and Continue
            $saveAndContinue = $ie.Document.getElementsByTagName('button') | Where-Object -FilterScript { $_.textContent -eq 'Save and Continue' }
            $saveAndContinue.click()

            # Wait for the page to load
            do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )

            # Determine what fields to show to the self-service kiosk
            $inputTypeOptions = $createMyStationButton = $ie.Document.getElementsByTagName('select') | Where-Object -FilterScript { $_.name -eq 'station[input_type_options]' }
            $inputTypeOptions.value = 'only_keypad'
            $inputMethod = $createMyStationButton = $ie.Document.getElementsByTagName('select') | Where-Object -FilterScript { $_.name -eq 'station[input_type]' }
            $inputMethod.value = 'keypad'

            # Click Save and Continue
            $saveAndContinue = $ie.Document.getElementsByTagName('button') | Where-Object -FilterScript { $_.textContent -eq 'Save and Continue' }
            $saveAndContinue.click()

            # Wait for the page to load
            do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )

            # Click Finish
            $finish = $ie.Document.getElementsByTagName('input') | Where-Object -FilterScript { $_.value -eq 'Finish' }
            $finish.click()

            # Wait for the page to load
            do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )

            # Navigate to the self-service kiosk
            $ie.Navigate($checkinURL)

            # Wait for the page to load
            do { Start-Sleep -Seconds 2 } while ( $ie.Busy -or ( $ie.ReadyState -ne 4 ) )
        }
        #>

        # Set it to kiosk mode
        $ie.FullScreen = $true
        
        # make the page visible
        $ie.Visible = $true

        # Bring the IE window to the front
        [void] [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
        [Microsoft.VisualBasic.Interaction]::AppActivate((Get-Process | Where-Object { $_.MainWindowHandle -eq $ie.HWND } | Select-Object -ExpandProperty Id))
        
        # Create a style element to only allow scrolling
        # This is a workaround to disabling double-tap to zoom
        $zoomStyleNode = $ie.Document.createElement('style')
        $zoomStyleNode.innerHTML = 'html { touch-action: pan-x pan-y; }'
        
        do
        {
            # Inject the style element into the document body
            $ie.Document.getElementsByTagName('body')[0].appendChild($zoomStyleNode) | Out-Null

            # Sleep so we don't use ALL the CPU
            # 100 ms seems to be frequent enough that somebody can't double-tap
            Start-Sleep -Milliseconds 100
        }
        while ( $true )
    }
}

End
{
    # Set the error action preference back
    $ErrorActionPreference = $originalErrorActionPreference

    # Pause at the end
    Start-Sleep -Seconds 5
}
