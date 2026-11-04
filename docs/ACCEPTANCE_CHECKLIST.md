# Release device acceptance

Run these checks on the exact build submitted to TestFlight using a test centre and synthetic patient records.

| Area | Check |
| --- | --- |
| Archive | Xcode validates the archive, bundle identifier, version, signing team, marketing icon and privacy resources. Review the generated Privacy Report. |
| Login | Check Doctor and Admin, single and multiple centres, unavailable centre, incorrect credentials, entitlement denial, expiry, Wi-Fi and cellular connectivity. |
| Secure storage | Verify Remember Me, relaunch, account switch, password change and logout. |
| Portrait and text | Rotate a small iPhone and supported iPad. Check the Login button above the keyboard and all four Dashboard tabs at large system text. |
| Clinical workflows | Check appointments, patient lookup, progress and prescription creation using synthetic data. |
| Camera, reports and calls | Test camera and photo permissions, reports, prescription previews, save/share/print and an authorized video link. |
| Payments and admin | Confirm role restrictions and use test transactions for payments, HR, accounts and reports. |
| Policy and review | Open Privacy Policy on Login and Dashboard. Verify the support and policy URLs, privacy labels, reviewer access and actual iOS screenshots. |
