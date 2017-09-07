$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = '*'

            # User information
            AdminUserName = 'McBIC Admin'
            CheckInUserName = 'Check In'

            # Pull server information
            PullShareName = 'ConfigurationSource'
            PullSharePath = 'C:\Repos\McBICKids\Checkin_Kiosk'

            # Branding
            BackgroundImagePath = 'C:\Repos\McBICKids\Images\Background.png'

            # User Experience settings
            InternetExplorerZoomLevel = 95 # Zoom level in Percent
        },
        @{
            NodeName = 'localhost'
        }
    )
}