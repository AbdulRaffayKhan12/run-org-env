# Start script
$currentDir = (Get-Location).Path
Write-Host "Current directory: $currentDir"

# Pre-check for gcloud CLI
if (-not (Get-Command "gcloud" -ErrorAction SilentlyContinue)) {
    Write-Host "`nGoogle Cloud CLI (gcloud) not found on your system."
    Write-Host "Downloading and installing Google Cloud SDK..."

    $tempInstallerPath = "$env:TEMP\google-cloud-sdk-installer.exe"

    try {
        $installerUrl = "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe"
        Invoke-WebRequest -Uri $installerUrl -OutFile $tempInstallerPath -UseBasicParsing
        Write-Host "Downloaded installer to $tempInstallerPath"

        $installArgs = "/S"
        $process = Start-Process -FilePath $tempInstallerPath -ArgumentList $installArgs -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            Write-Host "Google Cloud SDK installer failed with exit code $($process.ExitCode). Exiting."
            exit 1
        }

        Write-Host "Google Cloud SDK installed successfully."

        $defaultPath = "$env:ProgramFiles\Google\Cloud SDK\google-cloud-sdk\bin"
        $altPath = "$env:ProgramFiles(x86)\Google\Cloud SDK\google-cloud-sdk\bin"
        $userPath = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"

        if (Test-Path $defaultPath) {
            $env:Path = "$defaultPath;$env:Path"
            Write-Host "gcloud is now available at: $defaultPath"
        } elseif (Test-Path $altPath) {
            $env:Path = "$altPath;$env:Path"
            Write-Host "gcloud is now available at: $altPath"
        } elseif (Test-Path $userPath) {
            $env:Path = "$userPath;$env:Path"
            Write-Host "gcloud is now available at: $userPath"
        } else {
            Write-Host "Warning: Could not find gcloud path after installation in any known location."
        }

    } catch {
        Write-Host "Error installing Google Cloud SDK: $_"
        exit 1
    }
} else {
    Write-Host "`nGoogle Cloud CLI (gcloud) is installed."
}

# ---------------- AUTH CHECK ----------------
try {
    $account = & gcloud auth list --filter=status:ACTIVE --format="value(account)"
    if (-not $account) {
        Write-Host "`nYou are not logged into gcloud. Starting authentication..."
        Write-Host "Please open the URL shown in the terminal in a browser, log in, and paste the token here."

        & gcloud auth login --no-launch-browser --brief

        # Re-check login
        $account = & gcloud auth list --filter=status:ACTIVE --format="value(account)"
        if (-not $account) {
            Write-Host "❌ Login did not complete successfully. Exiting."
            exit 1
        } else {
            Write-Host "✅ Successfully logged in as: $account"
        }
    } else {
        Write-Host "✅ Already logged in as: $account"
    }
} catch {
    Write-Host "❌ Error running 'gcloud auth list'. Make sure gcloud CLI is installed correctly."
    exit 1
}

# ------------- CONFIG LOGIC -----------------

function Find-ConfigFile {
    param([string]$startDir, [string]$fileName)

    $currentDir = Get-Item -LiteralPath $startDir
    while ($currentDir -ne $null) {
        $candidate = Join-Path $currentDir.FullName $fileName
        if (Test-Path $candidate) { return $candidate }
        $currentDir = $currentDir.Parent
    }
    return $null
}

function Find-ApiproxyParentFolderDown {
    param (
        [string]$startDir,
        [string[]]$targetFolderNames = @("apiproxy")
    )

    $foundFolders = Get-ChildItem -Path $startDir -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $targetFolderNames -contains $_.Name.ToLower()
    }

    if ($foundFolders.Count -gt 0) {
        return $foundFolders[0].Parent.FullName
    } else {
        return $null
    }
}

$configFileName = "org-config.txt"
$configPath = Find-ConfigFile -startDir $currentDir -fileName $configFileName
$configDir = if ($configPath) { Split-Path $configPath -Parent } else { $null }

if (-not $configPath) {
    $apiproxyFolderParent = Find-ApiproxyParentFolderDown -startDir $currentDir

    if ($apiproxyFolderParent) {
        $configPath = Join-Path $apiproxyFolderParent $configFileName
        $configDir = $apiproxyFolderParent
        Write-Host "Creating '${configFileName}' in folder: $apiproxyFolderParent"
    } else {
        $configPath = Join-Path $currentDir $configFileName
        $configDir = $currentDir
        Write-Host "Creating '${configFileName}' in current directory: $currentDir"
    }

    "" | Out-File -FilePath $configPath -Encoding utf8
} else {
    Write-Host "Found '${configFileName}' at: $configPath"
}

function Prompt-Selection($items, $prompt) {
    if (-not $items -or $items.Count -eq 0) {
        Write-Host "No ${prompt} found. Exiting."
        exit 1
    }

    Write-Host "`nSelect ${prompt}:"
    for ($i = 0; $i -lt $items.Count; $i++) {
        Write-Host "$($i + 1)) $($items[$i])"
    }

    $choice = Read-Host "Enter choice number (or 'q' to quit)"
    if ($choice -eq 'q') { exit 0 }

    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $items.Count) {
        Write-Host "Invalid selection. Exiting."
        exit 1
    }

    return $items[$index]
}

# ------------------ Fetching Organizations ------------------
Write-Host "`nFetching Apigee organizations..."
try {
    $orgsOutput = & gcloud apigee organizations list --format="value(name)"
    $orgsArray = $orgsOutput -split "`n" | Where-Object { $_.Trim() -ne "" }

    if (-not $orgsArray -or $orgsArray.Count -eq 0) {
        Write-Host "No Apigee organizations found for your account."
        exit 1
    }
} catch {
    Write-Host "Failed to fetch organizations: $_"
    exit 1
}

$selectedOrg = Prompt-Selection -items $orgsArray -prompt "organization"

Write-Host "`nSetting gcloud project to '$selectedOrg' ..."
try {
    & gcloud config set project $selectedOrg | Out-Null
} catch {
    Write-Host "Failed to set gcloud project to '$selectedOrg'."
    exit 1
}
# ------------------ Fetching Environments ------------------
Write-Host "`nFetching environments for org: $selectedOrg ..."
try {
    $envsOutput = & gcloud apigee environments list 
    $envsArray = $envsOutput -split "`n" | ForEach-Object { $_.Trim().TrimStart('-').Trim() } | Where-Object { $_ -ne "" }

    if (-not $envsArray -or $envsArray.Count -eq 0) {
        Write-Host "No environments found in organization '$selectedOrg'."
        exit 1
    }
} catch {
    Write-Host "Failed to fetch environments: $_"
    exit 1
}

$selectedEnv = Prompt-Selection -items $envsArray -prompt "environment"

@"
org=$selectedOrg
env=$selectedEnv
"@ | Out-File -FilePath $configPath -Encoding utf8

Write-Host "`nSaved org and env to: $configPath"

Push-Location $configDir
try {
    # ------------------ GIT IDENTITY CHECK ------------------
    $gitName = git config user.name
    $gitEmail = git config user.email

    if (-not $gitName -or -not $gitEmail) {
        Write-Host "`n⚠ Git identity is not configured for this repo."
        $gitName = Read-Host "Enter your Git name"
        $gitEmail = Read-Host "Enter your Git email"

        git config user.name "$gitName"
        git config user.email "$gitEmail"
        Write-Host "✅ Git identity set locally: $gitName <$gitEmail>"
    } else {
        Write-Host "✅ Git identity already configured: $gitName <$gitEmail>"
    }

    Write-Host "`nStaging your changes in directory: $configDir"
    git add .

    Write-Host "`nEnter your commit message:"
    $commitMessage = Read-Host

    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        Write-Host "Commit message cannot be empty. Exiting."
        exit 1
    }

    Write-Host "`nCommitting your changes..."
    git commit -m "$commitMessage"

    Write-Host "`nPushing changes to remote repository (main branch)..."
    Write-Host "👉 If prompted, use GitHub username and a Personal Access Token (not your password)."
    git push origin main
}
finally {
    Pop-Location
}

Write-Host "Deploying your API proxy to the selected environment '$selectedEnv' in organization '$selectedOrg'..."
