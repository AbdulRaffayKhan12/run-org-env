# API-Dev-Bot

API-Dev-Bot is a Visual Studio Code extension that simplifies the process of selecting Apigee organizations and environments using Google Cloud CLI (`gcloud`) for seamless Apigee API proxy deployment.

## Features & Workflow

### 🗂️ Detects Your Current Directory
- Displays the working directory where the script is being run.

### ☁️ Installs Google Cloud SDK if Missing
- Checks if the `gcloud` CLI is installed.
- If not found, it downloads and installs the SDK silently.

### 🔐 Authenticates with Google Cloud
- Checks whether you're already authenticated with `gcloud`.
- If not, it triggers an interactive login through the terminal.


### 🏢 Lists Your Apigee Organizations
- Uses `gcloud` to fetch a list of Apigee organizations linked to your Google Cloud account.
- Prompts you to select one via a numbered list.

### 🌎 Lists Environments for the Selected Org
- After selecting an organization, fetches its environments.
- Allows you to choose an environment interactively.

### 📄 Saves Config to `org-config.txt`
- Automatically writes your selected `org` and `env` to the config file.
- This ensures you don't have to repeat the process every time.

### 📤 Git Automation
- Stages all changes in your project directory.
- Prompts you for a commit message.
- Commits and pushes the changes to the `main` branch.

### 🚀 API Proxy Deployment
- Once everything is configured, the script deploys your API proxy to the selected Apigee environment.
