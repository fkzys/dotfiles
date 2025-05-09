//my own

user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.always_ask_before_handling_new_types", false);

//https://github.com/arkenfox/user.js/issues/1080

/* override recipe: enable session restore ***/
user_pref("browser.startup.page", 3); // 0102
  // user_pref("browser.privatebrowsing.autostart", false); // 0110 required if you had it set as true
  // user_pref("browser.sessionstore.privacy_level", 0); // 1003 optional to restore cookies/formdata
user_pref("privacy.clearOnShutdown_v2.historyFormDataAndDownloads", false); // 2811 FF128-135
user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", false); // 2812 FF136+

// optional to match when you use settings>Cookies and Site Data>Clear Data
  // user_pref("privacy.clearSiteData.historyFormDataAndDownloads", false); // 2820 FF128-135
  // user_pref("privacy.clearSiteData.browsingHistoryAndDownloads", false); // 2821 FF136+

// optional to match when you use Ctrl-Shift-Del (settings>History>Custom Settings>Clear History)
  // user_pref("privacy.clearHistory.historyFormDataAndDownloads", false); // 2830 FF128-135
  // user_pref("privacy.clearHistory.browsingHistoryAndDownloads", false); // 2831 FF136+

// These are changes made on top of the Arkenfox JS file to tweak it as
// desired. Any of these settings can be overridden by the user.




//https://github.com/tatsumoto-ren/dotfiles/blob/main/.config/firefox/larbs.js

// Disable the Twitter/R*ddit/Faceberg ads in the URL bar:
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.suggest.topsites", false); // [FF78+]

// Do not suggest web history in the URL bar:
user_pref("browser.urlbar.suggest.history", false);

// Do not prefil forms:
user_pref("signon.prefillForms", false);

// Do not autocomplete in the URL bar:
user_pref("browser.urlbar.autoFill", false);

// Enable the addition of search keywords:
user_pref("keyword.enabled", true);

// Allow access to http (i.e. not https) sites:
user_pref("dom.security.https_only_mode", false);

// Keep cookies until expiration or user deletion:
user_pref("network.cookie.lifetimePolicy", 0);

user_pref("dom.webnotifications.serviceworker.enabled", false);

// Disable push notifications:
user_pref("dom.push.enabled", false);

// Disable the pocket antifeature:
user_pref("extensions.pocket.enabled", false);

// Don't autodelete cookies on shutdown:
// Did not work, so set to false
//user_pref("privacy.clearOnShutdown_v2.cookies", false);

// Enable custom userChrome.js:
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// This could otherwise cause some issues on bank logins and other annoying sites:
user_pref("network.http.referer.XOriginPolicy", 0);

// Disable Firefox sync and its menu entries
user_pref("identity.fxaccounts.enabled", false);

// Fix the issue where right mouse button instantly clicks
user_pref("ui.context_menus.after_mouseup", true);

