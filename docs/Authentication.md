# Authentication

## Overview

OpenDig integrates with various identity providers using [OmniAuth](https://github.com/omniauth/omniauth) to allow users to sign in and out of the application. The following sections describe how to configure these integrations. OpenDig itself is configured through environment variables set in the `.envrc` file. For more information about `.envrc`, see [README.md](../README.md) and [.envrc.example](../.envrc.example).

In development, OpenDig also supports quickly creating developer accounts using OmniAuth's built-in developer strategy. Simply navigate to <http://localhost:3000/auth/developer> to create an account for manual testing.

Currently supported IDPs: [Google](#google), [GitHub](#github), [Microsoft](#microsoft-office-365organizationboth)

## Google

OAuth2 with Google requires two credentials: a client ID and a client secret. These are set in the `.envrc` file as `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`. To get these credentials, you will need to create an application on the [Google Cloud Console](https://console.cloud.google.com/apis/dashboard).

Relevant documentation at [support.google.com](https://support.google.com/cloud/answer/15544987)

### Set up a Google Cloud application

1. Create a new project in the Google Cloud Console
2. Configure your OAuth flow
    * Navigate to "OAuth consent screen" and fill out the form
    * Navigate to "Data Access" and select "Add or remove scopes"
    * Select these scopes: `.../auth/userinfo.profile`, `.../auth/userinfo.email`, and `openid`
        * These are the scopes OpenDig uses to authenticate a user. Authentication with Google will likely not work without them
    * Click "Save"
3. Set up credentials for your OpenDig instance
    * Navigate to "Overview" and click on "Create OAuth client"
    * Select "Web application" as the application type
    * Add an authorized redirect URI: `http(s)://your-domain.com/auth/google_oauth2/callback`
        * For development/testing, use: `http://localhost:3000/auth/google_oauth2/callback`
    * Click "Create"
    * Copy the client secret shown in the confirmation dialog. Save it to your `.envrc` file as `GOOGLE_CLIENT_SECRET`
        * Do this before closing the dialog as __you will not be able to see the secret again__
    * Copy the client ID shown in the confirmation dialog. Save it in your `.envrc` file as `GOOGLE_CLIENT_ID`
4. Launch (or relaunch) your OpenDig instance and test it out!

## Microsoft (Office 365/organization/both)

OAuth2 with Microsoft requires two credentials: a client ID and a client secret. These are set in the `.envrc` file as `MICROSOFT_CLIENT_ID` and `MICROSOFT_CLIENT_SECRET`. To get these credentials, you will need to create an application in the [Microsoft Entra admin center](https://entra.microsoft.com/#home).

Relevant documentation at [learn.microsoft.com](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/add-application-portal-setup-oidc-sso)

### Set up a Microsoft Enterprise App

1. Create an Enterprise App
    * Navigate to "Enterprise Apps" > "All Applications" and click "New Application"
    * Enter a name, then select "Register an application to integrate with Microsoft Entra ID (App you're developing)"
    * Depending on your intended use case, select the correct option under "Supported account types"
        * For the widest compatibility, choose "Accounts in any organizational directory and personal Microsoft accounts". This is the recommended option
    * Add a redirect URI: `http(s)://your-domain.com/auth/microsoft_office365/callback` with platform "Web"
        * For development/testing, use: `http://localhost:3000/auth/microsoft_office365/callback`
    * Click "Register"
2. Configure your OAuth flow
    * Navigate to "App registrations" > "All apps"
    * Select your app
    * In the "API permissions" pane, add these permissions: `offline_access` and `openid`. `User.Read` should be selected by default
        * These can be found under "Microsoft Graph" > "Delegated permissions" > "OpenId permissions"
        * These are the permissions OpenDig uses to authenticate a user. Authentication with Microsoft will likely not work without them
3. Set up credentials for your OpenDig instance
    * Navigate to "App registrations" > "All apps"
    * Select your app
    * In the "Overview" pane, in the "Essentials" section, click "Add a certificate or secret" then "New client secret"
    * Enter a description and expiration date and confirm
    * Copy the secret, shown in the "Value" column. Save it in your `.envrc` file as `MICROSOFT_CLIENT_SECRET`
        * Do this before closing the dialog as __you will not be able to see the secret again__
    * Navigate back to the "Overview" pane
    * In the "Essentials" section, copy the client ID, labeled "Application (client) ID". Save it in your `.envrc` file as `MICROSOFT_CLIENT_ID`
4. Launch (or relaunch) your OpenDig instance and test it out!

## GitHub

OAuth2 with GitHub requires two credentials: a client ID and a client secret. These are set in the `.envrc` file as `MICROSOFT_CLIENT_ID` and `MICROSOFT_CLIENT_SECRET`. To get these credentials, you will need to create an OAuth App in the [GitHub developer settings](https://github.com/settings/apps).

Relevant documentation at [docs.github.com](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app)

### Set up a GitHub OAuth App

1. Create an OAuth App
    * Click "New OAuth App"
    * Fill out the form
    * Enter an authorization callback URL: `http(s)://your-domain.com/auth/github/callback`
        * For development/testing, use: `http://localhost:3000/auth/github/callback`
    * Ensure "Enable Device Flow" is __not checked__
    * Click "Register application"
2. Set up credentials for your OpenDig instance
    * Click "Generate a new client secret"
    * Copy the secret. Save it in your `.envrc` file as `MICROSOFT_CLIENT_SECRET`
        * Do this before closing the dialog as __you will not be able to see the secret again__
    * Click "Update application"
    * Copy the client ID. Save it in your `.envrc` file as `GITHUB_CLIENT_ID`
3. Launch (or relaunch) your OpenDig instance and test it out!
