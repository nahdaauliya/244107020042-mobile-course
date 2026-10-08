## Screenshot Evidence

The following screenshot files are provided as evidence of the FCM notification implementation and testing:

1. **`fcm_token.png`** — Displays the truncated FCM Registration Token obtained from the debug console or terminal.
2. **`foreground_banner.png`** — Shows the local notification banner displayed when the application is running in the foreground.
3. **`background_banner.png`** — Shows the system notification banner received while the application is running in the background.
4. **`terminated_banner.png`** — Shows the system notification banner received when the application is completely terminated.
5. **`deeplink_destination.png`** — Shows the `/announcement/3` destination page opened after the user taps the notification banner.

### Testing Checklist

[x] FCM Registration Token generated and truncated
[x] Foreground notification tested
[x] Background notification tested
[x] Terminated-state notification tested
[x] Deep link to `/announcement/3` tested
