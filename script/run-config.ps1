
# Function to find org-config.txt upwards in folder hierarchy
function Find-ConfigFile {
    param([string]$startDir, [string]$fileName)

    $currentDir = Get-Item -LiteralPath $startDir

    while ($currentDir -ne $null) {
        $candidate = Join-Path $currentDir.FullName $fileName
        if (Test-Path $candidate) {
            return $candidate
        }
        $currentDir = $currentDir.Parent
    }
    return $null
}

# Function to find apiproxy or apiproxies folder downward from startDir
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

# Start script
$currentDir = (Get-Location).Path
Write-Host "Current directory: $currentDir"

$configFileName = "org-config.txt"

# Try to find existing org-config.txt upward
$configPath = Find-ConfigFile -startDir $currentDir -fileName $configFileName
$configDir = if ($configPath) { Split-Path $configPath -Parent } else { $null }

if (-not $configPath) {
    # Search downward for apiproxy folder
    $apiproxyFolderParent = Find-ApiproxyParentFolderDown -startDir $currentDir

    if ($apiproxyFolderParent) {
        $configPath = Join-Path $apiproxyFolderParent $configFileName
        $configDir = $apiproxyFolderParent
        Write-Host "Creating '${configFileName}' in folder: $apiproxyFolderParent"
    } else {
        # fallback to current directory
        $configPath = Join-Path $currentDir $configFileName
        $configDir = $currentDir
        Write-Host "Could not find 'apiproxy' folder downward. Creating '${configFileName}' in current directory: $currentDir"
    }
    # Create empty config file
    "" | Out-File -FilePath $configPath -Encoding utf8
} else {
    Write-Host "Found '${configFileName}' at: $configPath"
}

# Function to prompt selection
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

# Check gcloud login
try {
    $account = & gcloud auth list --filter=status:ACTIVE --format="value(account)"
    if (-not $account) {
        Write-Host "❌ You are not logged into gcloud. Please run 'gcloud auth login' first."
        exit 1
    } else {
        Write-Host "✅ Logged in as: $account"
    }
} catch {
    Write-Host "❌ Error running 'gcloud auth list'. Make sure gcloud CLI is installed."
    exit 1
}

# Fetch organizations
Write-Host "`nFetching Apigee organizations available to you..."
try {
    $orgsOutput = & gcloud apigee organizations list --format="value(name)"
    $orgsArray = $orgsOutput -split "`n" | Where-Object { $_.Trim() -ne "" }

    if (-not $orgsArray -or $orgsArray.Count -eq 0) {
        Write-Host "❌ No Apigee organizations found for your account."
        exit 1
    }
} catch {
    Write-Host "❌ Failed to fetch organizations: $_"
    exit 1
}

# Prompt for org selection
$selectedOrg = Prompt-Selection -items $orgsArray -prompt "organization"

# Set the gcloud project to the selected org (assuming org name = project ID)
Write-Host "`nSetting gcloud project to '$selectedOrg' ..."
try {
    & gcloud config set project $selectedOrg | Out-Null
} catch {
    Write-Host "❌ Failed to set gcloud project to '$selectedOrg'."
    exit 1
}

# Fetch environments using current project (set above)
Write-Host "`nFetching environments for org: $selectedOrg ..."
try {
    $envsOutput = & gcloud apigee environments list 
    # Clean each environment string: trim spaces and remove leading '-'
    $envsArray = $envsOutput -split "`n" | ForEach-Object { $_.Trim().TrimStart('-').Trim() } | Where-Object { $_ -ne "" }

    if (-not $envsArray -or $envsArray.Count -eq 0) {
        Write-Host "⚠️  No environments found in organization '$selectedOrg'."
        exit 1
    }
} catch {
    Write-Host "❌ Failed to fetch environments: $_"
    exit 1
}

# Prompt for environment selection
$selectedEnv = Prompt-Selection -items $envsArray -prompt "environment"

# Save to config file
@"
org=$selectedOrg
env=$selectedEnv
"@ | Out-File -FilePath $configPath -Encoding utf8

Write-Host "`nSaved org and env to: $configPath"

# Git commands - ALL RUN IN THE CONFIG DIRECTORY
Push-Location $configDir
try {
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
    git push origin main
}
finally {
    Pop-Location
}

Write-Host "Deploying your api proxy to the selected environment '$selectedEnv' in organization '$selectedOrg'..."
