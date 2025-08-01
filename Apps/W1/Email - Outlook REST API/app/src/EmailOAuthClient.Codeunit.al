// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Email;

using System.Environment;
using System.Security.Authentication;
using System.Azure.Identity;
using System.Utilities;

codeunit 4507 "Email - OAuth Client" implements "Email - OAuth Client v2"
{

    /// <summary>
    /// Retrieves the Access token for the current user to connect to Outlook API
    /// </summary>
    /// <param name="AccessToken">Out parameter with the Access token of the account</param>
    [NonDebuggable]
    procedure GetAccessToken(var AccessToken: SecretText)
    var
        CallerModuleInfo: ModuleInfo;
    begin
        NavApp.GetCallerModuleInfo(CallerModuleInfo);
        TryGetAccessTokenInternal(AccessToken, CallerModuleInfo);
    end;

    [NonDebuggable]
    procedure TryGetAccessToken(var AccessToken: SecretText): Boolean
    var
        CallerModuleInfo: ModuleInfo;
    begin
        NavApp.GetCallerModuleInfo(CallerModuleInfo);
        exit(TryGetAccessTokenInternal(AccessToken, CallerModuleInfo));
    end;

    local procedure CheckIfThirdParty(CallerModuleInfo: ModuleInfo)
    var
        EnvironmentInformation: Codeunit "Environment Information";
        CurrentModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CurrentModuleInfo);

        if EnvironmentInformation.IsSaaSInfrastructure() <> true then
            exit;

        if CallerModuleInfo.Publisher <> CurrentModuleInfo.Publisher then
            Error(ThirdPartyExtensionsNotAllowedErr);
    end;


    // Interfaces do not support properties for the procedures, so using an internal function
    [TryFunction]
    [NonDebuggable]
    local procedure TryGetAccessTokenInternal(var AccessToken: SecretText; CallerModuleInfo: ModuleInfo)
    var
        AzureAdMgt: Codeunit "Azure AD Mgt.";
        UrlHelper: Codeunit "Url Helper";
        EnvironmentInformation: Codeunit "Environment Information";
        OAuthErr: Text;
        IsHandled: Boolean;
    begin
        OnBeforeGetToken(IsHandled);
        if IsHandled then
            exit;

        CheckIfThirdParty(CallerModuleInfo);
        Initialize();

        ClearLastError();
        if EnvironmentInformation.IsSaaSInfrastructure() then begin
            AccessToken := AzureAdMgt.GetAccessTokenAsSecretText(UrlHelper.GetGraphUrl(), '', false);
            if AccessToken.IsEmpty() then begin
                Session.LogMessage('000040Z', CouldNotAcquireAccessTokenErr, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', EmailCategoryLbl);
                if OAuth2.AcquireOnBehalfOfToken('', Scopes, AccessToken) then;
            end;
        end else
            if (not OAuth2.AcquireAuthorizationCodeTokenFromCache(ClientId, ClientSecret, RedirectURL, GetOAuthAuthorityUrl(), Scopes, AccessToken)) or AccessToken.IsEmpty() then
                OAuth2.AcquireTokenByAuthorizationCode(ClientId, ClientSecret, GetOAuthAuthorityUrl(), RedirectURL, Scopes, Enum::"Prompt Interaction"::None, AccessToken, OAuthErr);

        if AccessToken.IsEmpty() then begin
            if AzureADMgt.GetLastErrorMessage() <> '' then
                Error(AzureADMgt.GetLastErrorMessage());

            Error(CouldNotGetAccessTokenErr);
        end
    end;

    internal procedure GetLastAuthorizationErrorMessage(): Text
    begin
        exit(OAuth2.GetLastErrorMessage());
    end;

    local procedure Initialize()
    var
        EnvironmentInformation: Codeunit "Environment Information";
        EmailOutlookAPIHelper: Codeunit "Email - Outlook API Helper";
    begin
        if IsInitialized then
            exit;

        Scopes.Add(GraphScopesLbl);
        if not EnvironmentInformation.IsSaaSInfrastructure() then begin
            EmailOutlookAPIHelper.GetClientIDAndSecret(ClientId, ClientSecret);
            RedirectURL := EmailOutlookAPIHelper.GetRedirectURL();
            if RedirectURL = '' then
                OAuth2.GetDefaultRedirectUrl(RedirectURL);
        end;

        IsInitialized := true;
    end;

    internal procedure AuthorizationCodeTokenCacheExists(): Boolean
    var
        AccessToken: SecretText;
    begin
        Initialize();
        exit(OAuth2.AcquireAuthorizationCodeTokenFromCache(ClientId, ClientSecret, RedirectURL, GetOAuthAuthorityUrl(), Scopes, AccessToken) and (not AccessToken.IsEmpty()))
    end;

    internal procedure SignInUsingAuthorizationCode(): Boolean
    var
        AccessToken: SecretText;
        OAuthErr: Text;
    begin
        Initialize();
        exit(OAuth2.AcquireTokenByAuthorizationCode(ClientID, ClientSecret, GetOAuthAuthorityUrl(), RedirectURL, Scopes, Enum::"Prompt Interaction"::"Select Account", AccessToken, OAuthErr) and (not AccessToken.IsEmpty()));
    end;

    local procedure GetOAuthAuthorityUrl(): Text
    var
        UrlHelper: Codeunit "Url Helper";
        AuthUrl: Text;
    begin
        AuthUrl := UrlHelper.GetAzureADAuthEndpoint();
        exit(AuthUrl.Replace('/authorize', ''));
    end;

    // This event is ONLY used for testing purposes. This can help us to mock the GetAccessToken function. Never use this event in production code.
    [InternalEvent(false)]
    local procedure OnBeforeGetToken(var IsHandled: Boolean)
    begin
    end;

    var
        OAuth2: Codeunit OAuth2;
        [NonDebuggable]
        ClientId: Text;
        ClientSecret: SecretText;
        RedirectURL: Text;
        IsInitialized: Boolean;
        Scopes: List of [Text];
        GraphScopesLbl: Label 'https://graph.microsoft.com/.default', Locked = true;
        CouldNotGetAccessTokenErr: Label 'Could not get access token.';
        EmailCategoryLbl: Label 'EmailOAuth', Locked = true;
        CouldNotAcquireAccessTokenErr: Label 'Failed to acquire access token.', Locked = true;
        ThirdPartyExtensionsNotAllowedErr: Label 'Third-party extensions are restricted from obtaining access tokens. Please contact your system administrator.';
}