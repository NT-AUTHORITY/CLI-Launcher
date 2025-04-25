# Authentication.ps1
# Module for handling Minecraft account authentication

# Load necessary .NET types
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Security

# Authentication module functions

# Generate a code verifier for PKCE
function New-CodeVerifier {
    $randomBytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($randomBytes)
    $base64 = [Convert]::ToBase64String($randomBytes)
    $base64 = $base64.Replace("+", "-").Replace("/", "_").Replace("=", "")
    return $base64.Substring(0, 43)
}

# Generate a code challenge from a code verifier
function New-CodeChallenge {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CodeVerifier
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $challengeBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($CodeVerifier))
    $base64 = [Convert]::ToBase64String($challengeBytes)
    return $base64.Replace("+", "-").Replace("/", "_").Replace("=", "")
}

# Generate an authorization URL
function New-AuthorizationUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CodeChallenge
    )

    $clientId = "00000000-0000-0000-0000-000000000000" # Replace with actual client ID
    $redirectUri = "http://localhost:8080"
    $microsoftOAuthUrl = "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize"

    return "$microsoftOAuthUrl?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&scope=XboxLive.signin%20offline_access&code_challenge=$CodeChallenge&code_challenge_method=S256&response_mode=query"
}

# Get Microsoft token
function Get-MicrosoftToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AuthCode,

        [Parameter(Mandatory = $true)]
        [string]$CodeVerifier
    )

    $clientId = "00000000-0000-0000-0000-000000000000" # Replace with actual client ID
    $redirectUri = "http://localhost:8080"
    $microsoftTokenUrl = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"

    $body = @{
        client_id = $clientId
        code = $AuthCode
        redirect_uri = $redirectUri
        grant_type = "authorization_code"
        code_verifier = $CodeVerifier
    }

    $response = Invoke-RestMethod -Uri $microsoftTokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    return $response.access_token
}

# Get Xbox Live token
function Get-XboxLiveToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MicrosoftToken
    )

    $xboxLiveUrl = "https://user.auth.xboxlive.com/user/authenticate"

    $body = @{
        Properties = @{
            AuthMethod = "RPS"
            SiteName = "user.auth.xboxlive.com"
            RpsTicket = "d=$MicrosoftToken"
        }
        RelyingParty = "http://auth.xboxlive.com"
        TokenType = "JWT"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $xboxLiveUrl -Method Post -Body $body -ContentType "application/json"
    return $response.Token
}

# Get XSTS token
function Get-XstsToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$XboxLiveToken
    )

    $xstsUrl = "https://xsts.auth.xboxlive.com/xsts/authorize"

    $body = @{
        Properties = @{
            SandboxId = "RETAIL"
            UserTokens = @($XboxLiveToken)
        }
        RelyingParty = "rp://api.minecraftservices.com/"
        TokenType = "JWT"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $xstsUrl -Method Post -Body $body -ContentType "application/json"
    return $response.Token
}

# Get Minecraft token
function Get-MinecraftToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$XstsToken,

        [Parameter(Mandatory = $true)]
        [string]$UserHash
    )

    $minecraftServicesUrl = "https://api.minecraftservices.com"
    $minecraftLoginUrl = "$minecraftServicesUrl/authentication/login_with_xbox"

    $body = @{
        identityToken = "XBL3.0 x=$UserHash;$XstsToken"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $minecraftLoginUrl -Method Post -Body $body -ContentType "application/json"
    return $response.access_token
}

# Check game ownership
function Test-GameOwnership {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftToken
    )

    $minecraftServicesUrl = "https://api.minecraftservices.com"
    $entitlementsUrl = "$minecraftServicesUrl/entitlements/mcstore"

    $headers = @{
        Authorization = "Bearer $MinecraftToken"
    }

    $response = Invoke-RestMethod -Uri $entitlementsUrl -Method Get -Headers $headers
    return $response.items.Count -gt 0
}

# Get player profile
function Get-PlayerProfile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftToken
    )

    $minecraftServicesUrl = "https://api.minecraftservices.com"
    $profileUrl = "$minecraftServicesUrl/minecraft/profile"

    $headers = @{
        Authorization = "Bearer $MinecraftToken"
    }

    $response = Invoke-RestMethod -Uri $profileUrl -Method Get -Headers $headers
    return @{
        id = $response.id
        name = $response.name
    }
}

# Start local HTTP server to receive OAuth callback
function Start-OAuthListener {
    param (
        [string]$Port = "8080",
        [int]$TimeoutSeconds = 120
    )

    Write-DebugLog -Message "Starting OAuth listener on port $Port" -Source "Authentication" -Level "Debug"

    try {
        # Create and configure HTTP listener
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$Port/")

        # Try to start the listener
        try {
            Write-DebugLog -Message "Starting HTTP listener" -Source "Authentication" -Level "Debug"
            $listener.Start()
            Write-DebugLog -Message "HTTP listener started successfully" -Source "Authentication" -Level "Debug"
        }
        catch {
            Write-DebugLog -Message "Failed to start HTTP listener: $($_.Exception.Message)" -Source "Authentication" -Level "Error"
            Write-Host "Failed to start authentication callback listener. Please make sure port $Port is available." -ForegroundColor Red
            return $null
        }

        Write-Host "Waiting for authentication callback... (Timeout: $TimeoutSeconds seconds)" -ForegroundColor Cyan
        Write-DebugLog -Message "Waiting for authentication callback with timeout of $TimeoutSeconds seconds" -Source "Authentication" -Level "Debug"

        # Set up timeout
        $startTime = Get-Date
        $timeoutTime = $startTime.AddSeconds($TimeoutSeconds)

        # Create a task to get the context with timeout
        $task = $listener.GetContextAsync()

        # Wait for the task to complete or timeout
        while (-not $task.IsCompleted) {
            Start-Sleep -Milliseconds 500

            # Check if timeout has been reached
            if ((Get-Date) -gt $timeoutTime) {
                Write-DebugLog -Message "Authentication callback timeout reached ($TimeoutSeconds seconds)" -Source "Authentication" -Level "Warning"
                Write-Host "Authentication timed out. Please try again." -ForegroundColor Red
                $listener.Stop()
                return $null
            }
        }

        # Get the context
        $context = $task.Result
        $request = $context.Request
        $response = $context.Response

        Write-DebugLog -Message "Received callback request from $($request.RemoteEndPoint.Address)" -Source "Authentication" -Level "Debug"

        # Get query parameters
        $code = $request.QueryString["code"]
        $errorCode = $request.QueryString["error"]

        # Check for error
        if ($errorCode) {
            $errorDescription = $request.QueryString["error_description"]
            Write-DebugLog -Message "Authentication error: $errorCode - $errorDescription" -Source "Authentication" -Level "Error"

            # Return error page
            $responseText = "<html><body><h1>Authentication Failed</h1><p>Error: $errorCode</p><p>Description: $errorDescription</p><p>Please close this window and try again.</p></body></html>"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseText)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()

            $listener.Stop()
            return $null
        }

        # Check for code
        if (-not $code) {
            Write-DebugLog -Message "No authorization code received in callback" -Source "Authentication" -Level "Error"

            # Return error page
            $responseText = "<html><body><h1>Authentication Failed</h1><p>No authorization code received.</p><p>Please close this window and try again.</p></body></html>"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseText)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()

            $listener.Stop()
            return $null
        }

        Write-DebugLog -Message "Authorization code received successfully" -Source "Authentication" -Level "Debug"

        # Return success page
        $responseText = "<html><body><h1>Authentication Successful!</h1><p>You can close this window and return to the launcher.</p></body></html>"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseText)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()

        $listener.Stop()

        Write-DebugLog -Message "OAuth listener stopped" -Source "Authentication" -Level "Debug"
        return $code
    }
    catch {
        Write-DebugLog -Message "Error in OAuth listener: $($_.Exception.Message)" -Source "Authentication" -Level "Error"

        # Make sure to stop the listener if it's running
        if ($listener -and $listener.IsListening) {
            try {
                $listener.Stop()
                Write-DebugLog -Message "OAuth listener stopped after error" -Source "Authentication" -Level "Debug"
            }
            catch {
                Write-DebugLog -Message "Failed to stop OAuth listener: $($_.Exception.Message)" -Source "Authentication" -Level "Debug"
            }
        }

        Handle-Error -ErrorRecord $_ -Source "Authentication" -CustomMessage "Error in OAuth listener" -Continue
        return $null
    }
}

# Execute authentication flow
function Invoke-Authentication {
    try {
        Write-DebugLog -Message "Starting authentication process" -Source "Authentication" -Level "Debug"

        # Generate PKCE verification code
        $codeVerifier = New-CodeVerifier
        $codeChallenge = New-CodeChallenge -CodeVerifier $codeVerifier
        Write-DebugLog -Message "Generated PKCE code challenge" -Source "Authentication" -Level "Debug"

        # Generate authorization URL
        $authUrl = New-AuthorizationUrl -CodeChallenge $codeChallenge
        Write-DebugLog -Message "Generated authorization URL" -Source "Authentication" -Level "Debug"

        # Open browser for authentication
        Write-DebugLog -Message "Opening browser for authentication" -Source "Authentication" -Level "Info"
        Write-Host "Opening browser for Microsoft account authentication..."

        # Try multiple methods to open the browser
        $browserOpenSuccess = $false

        # Method 1: Using Start-Process
        try {
            Write-DebugLog -Message "Attempting to open browser using Start-Process" -Source "Authentication" -Level "Debug"
            Start-Process $authUrl -ErrorAction Stop
            $browserOpenSuccess = $true
            Write-DebugLog -Message "Browser opened successfully using Start-Process" -Source "Authentication" -Level "Debug"
        }
        catch {
            Write-DebugLog -Message "Failed to open browser using Start-Process: $($_.Exception.Message)" -Source "Authentication" -Level "Debug"
        }

        # Method 2: Using Invoke-Expression with start command
        if (-not $browserOpenSuccess) {
            try {
                Write-DebugLog -Message "Attempting to open browser using start command" -Source "Authentication" -Level "Debug"
                Invoke-Expression "start $authUrl" -ErrorAction Stop
                $browserOpenSuccess = $true
                Write-DebugLog -Message "Browser opened successfully using start command" -Source "Authentication" -Level "Debug"
            }
            catch {
                Write-DebugLog -Message "Failed to open browser using start command: $($_.Exception.Message)" -Source "Authentication" -Level "Debug"
            }
        }

        # Method 3: Using Internet Explorer COM object
        if (-not $browserOpenSuccess) {
            try {
                Write-DebugLog -Message "Attempting to open browser using IE COM object" -Source "Authentication" -Level "Debug"
                $ie = New-Object -ComObject InternetExplorer.Application
                $ie.Navigate($authUrl)
                $ie.Visible = $true
                $browserOpenSuccess = $true
                Write-DebugLog -Message "Browser opened successfully using IE COM object" -Source "Authentication" -Level "Debug"
            }
            catch {
                Write-DebugLog -Message "Failed to open browser using IE COM object: $($_.Exception.Message)" -Source "Authentication" -Level "Debug"
            }
        }

        # If all methods failed, display the URL to the user
        if (-not $browserOpenSuccess) {
            Write-DebugLog -Message "All browser opening methods failed" -Source "Authentication" -Level "Warning"
            Write-Host "Could not open browser automatically. Please copy and paste the following URL into your browser:" -ForegroundColor Yellow
            Write-Host $authUrl -ForegroundColor Cyan
        }

        # Start local server to receive callback
        Write-DebugLog -Message "Starting OAuth listener" -Source "Authentication" -Level "Debug"
        $authCode = Start-OAuthListener

        if (-not $authCode) {
            Write-DebugLog -Message "No authorization code received" -Source "Authentication" -Level "Error"
            Write-Host "Authentication failed: No authorization code received" -ForegroundColor Red
            return
        }

        Write-DebugLog -Message "Authorization code received" -Source "Authentication" -Level "Debug"
        Write-Host "Processing authentication..." -ForegroundColor Cyan

        # Get Microsoft token
        Write-DebugLog -Message "Requesting Microsoft token" -Source "Authentication" -Level "Debug"
        $microsoftToken = Get-MicrosoftToken -AuthCode $authCode -CodeVerifier $codeVerifier
        Write-DebugLog -Message "Microsoft token received" -Source "Authentication" -Level "Debug"

        # Get Xbox Live token
        Write-DebugLog -Message "Requesting Xbox Live token" -Source "Authentication" -Level "Debug"
        $xboxLiveToken = Get-XboxLiveToken -MicrosoftToken $microsoftToken
        Write-DebugLog -Message "Xbox Live token received" -Source "Authentication" -Level "Debug"

        # Get XSTS token
        Write-DebugLog -Message "Requesting XSTS token" -Source "Authentication" -Level "Debug"
        $xstsToken = Get-XstsToken -XboxLiveToken $xboxLiveToken
        Write-DebugLog -Message "XSTS token received" -Source "Authentication" -Level "Debug"

        # Get user hash from Xbox Live token response
        $userHash = "userHash" # In a real implementation, extract this from the Xbox Live token response
        Write-DebugLog -Message "Using user hash: $userHash" -Source "Authentication" -Level "Debug"

        # Get Minecraft token
        Write-DebugLog -Message "Requesting Minecraft token" -Source "Authentication" -Level "Debug"
        $minecraftToken = Get-MinecraftToken -XstsToken $xstsToken -UserHash $userHash
        Write-DebugLog -Message "Minecraft token received" -Source "Authentication" -Level "Debug"

        # Check game ownership
        Write-DebugLog -Message "Checking game ownership" -Source "Authentication" -Level "Debug"
        $hasGame = Test-GameOwnership -MinecraftToken $minecraftToken

        if (-not $hasGame) {
            Write-DebugLog -Message "Account does not own Minecraft Java Edition" -Source "Authentication" -Level "Error"
            Write-Host "Authentication failed: Your account does not own Minecraft Java Edition" -ForegroundColor Red
            return
        }

        Write-DebugLog -Message "Game ownership confirmed" -Source "Authentication" -Level "Debug"

        # Get player profile
        Write-DebugLog -Message "Requesting player profile" -Source "Authentication" -Level "Debug"
        $playerProfile = Get-PlayerProfile -MinecraftToken $minecraftToken
        Write-DebugLog -Message "Player profile received: $($playerProfile.name)" -Source "Authentication" -Level "Debug"

        # Save authentication information
        $authInfo = @{
            AccessToken = $minecraftToken
            Username = $playerProfile.name
            UUID = $playerProfile.id
            ExpiresAt = (Get-Date).AddHours(24).ToString("o")
        }

        Save-AuthenticationInfo -AuthInfo $authInfo

        Write-DebugLog -Message "Authentication successful for user: $($playerProfile.name)" -Source "Authentication" -Level "Info"
        Write-Host "Authentication successful! Welcome, $($playerProfile.name)!" -ForegroundColor Green
    }
    catch {
        Write-DebugLog -Message "Authentication error: $($_.Exception.Message)" -Source "Authentication" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "Authentication" -CustomMessage "Error during authentication process"
    }
}

# Get authentication status
function Get-AuthenticationStatus {
    $configFile = Join-Path -Path $configPath -ChildPath "auth.json"

    if (-not (Test-Path -Path $configFile)) {
        return @{
            IsAuthenticated = $false
            Username = $null
        }
    }

    try {
        Write-DebugLog -Message "Reading authentication information" -Source "Authentication" -Level "Debug"
        $authInfo = Get-Content -Path $configFile -Raw | ConvertFrom-Json

        # Check if token is expired
        $expiresAt = [DateTime]::Parse($authInfo.ExpiresAt)
        if ($expiresAt -lt (Get-Date)) {
            Write-DebugLog -Message "Authentication token expired" -Source "Authentication" -Level "Debug"
            return @{
                IsAuthenticated = $false
                Username = $null
            }
        }

        # Check if this is an offline account
        $isOffline = $false
        if ($authInfo.PSObject.Properties.Name -contains "IsOffline" -and $authInfo.IsOffline) {
            $isOffline = $true
            Write-DebugLog -Message "Offline authentication valid for user: $($authInfo.Username)" -Source "Authentication" -Level "Debug"
        } else {
            Write-DebugLog -Message "Online authentication valid for user: $($authInfo.Username)" -Source "Authentication" -Level "Debug"
        }

        return @{
            IsAuthenticated = $true
            Username = $authInfo.Username
            UUID = $authInfo.UUID
            AccessToken = $authInfo.AccessToken
            IsOffline = $isOffline
        }
    }
    catch {
        Write-DebugLog -Message "Error reading authentication information: $($_.Exception.Message)" -Source "Authentication" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "Authentication" -CustomMessage "Error reading authentication information" -Continue
        return @{
            IsAuthenticated = $false
            Username = $null
        }
    }
}

# Save authentication information
function Save-AuthenticationInfo {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthInfo
    )

    $configFile = Join-Path -Path $configPath -ChildPath "auth.json"

    try {
        Write-DebugLog -Message "Saving authentication information" -Source "Authentication" -Level "Debug"
        $AuthInfo | ConvertTo-Json | Set-Content -Path $configFile
        Write-DebugLog -Message "Authentication information saved" -Source "Authentication" -Level "Debug"
        Write-Host "Authentication information saved" -ForegroundColor Green
    }
    catch {
        Write-DebugLog -Message "Error saving authentication information: $($_.Exception.Message)" -Source "Authentication" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "Authentication" -CustomMessage "Error saving authentication information" -Continue
    }
}

# Offline login function
function Invoke-OfflineLogin {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username
    )

    try {
        Write-DebugLog -Message "Starting offline login process for username: $Username" -Source "Authentication" -Level "Info"

        # Generate a random UUID for the user
        $uuid = [guid]::NewGuid().ToString("N")
        Write-DebugLog -Message "Generated UUID for offline user: $uuid" -Source "Authentication" -Level "Debug"

        # Create authentication info
        $authInfo = @{
            AccessToken = "offline_$uuid"  # Prefix with 'offline_' to identify offline tokens
            Username = $Username
            UUID = $uuid
            ExpiresAt = (Get-Date).AddYears(10).ToString("o")  # Long expiration for offline mode
            IsOffline = $true  # Flag to identify offline accounts
        }

        # Save authentication info
        Save-AuthenticationInfo -AuthInfo $authInfo

        Write-DebugLog -Message "Offline login successful for user: $Username" -Source "Authentication" -Level "Info"
        Write-Host "Offline login successful! Welcome, $Username!" -ForegroundColor Green

        return $true
    }
    catch {
        Write-DebugLog -Message "Error during offline login: $($_.Exception.Message)" -Source "Authentication" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "Authentication" -CustomMessage "Error during offline login"
        return $false
    }
}

# Logout
function Invoke-Logout {
    $configFile = Join-Path -Path $configPath -ChildPath "auth.json"

    Write-DebugLog -Message "Logging out" -Source "Authentication" -Level "Debug"
    if (Test-Path -Path $configFile) {
        Remove-Item -Path $configFile -Force
        Write-DebugLog -Message "User logged out successfully" -Source "Authentication" -Level "Info"
        Write-Host "Successfully logged out" -ForegroundColor Green
    }
    else {
        Write-DebugLog -Message "Logout attempted but user was not logged in" -Source "Authentication" -Level "Warning"
        Write-Host "You are not logged in" -ForegroundColor Yellow
    }
}
