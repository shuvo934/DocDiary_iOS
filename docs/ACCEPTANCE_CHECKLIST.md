# M1 iPhone acceptance — all device checks currently pending

Record the iPhone model, iOS version, Flutter version, native Android baseline version,
test centre and non-sensitive account role. Do not place real passwords in this file.

| Check | Expected | Result |
| --- | --- | --- |
| Mac setup/analyzer/tests | Commands exit successfully; record actual output | Pending |
| Simulator compilation | Debug iOS build completes | Pending |
| Physical iPhone signing/run | Correct app installs and opens | Pending |
| Login visual comparison | Artwork, colours, text, fonts, margins and scrolling compared with Android | Pending |
| Small screen and keyboard | Both inputs and login remain reachable; no clipping | Pending |
| Wrong credentials | Native server rejection appears; no session saved | Pending |
| Single centre doctor/admin | Correct role-specific account is selected | Pending |
| Multiple centres | Every expected centre appears and correct API is selected | Pending |
| Multiple doctors/admins/mixed | Names, role and selected identifier match Android | Pending |
| Cancel selection | No successful login; entered form can be resumed | Pending |
| Server unavailable | Retryable error; other valid centres remain available | Pending |
| Forced logout/access disabled/expired | Access denied; protected data is not displayed | Pending |
| First-login expiry/audit | Headers/server changes match intended native semantics | Pending |
| Remember Me on/off | Filled form and post-logout behaviour match Android | Pending |
| iOS update/no listing/current version | Compatible newer Store version blocks before session restore; no listing/current permits routing | Pending iPhone/Store |
| iOS update failure/Cancel/Retry | Store launch/return failure retains gate and native failure text; iOS Home instruction on final Cancel | Pending iPhone/Store |
| Device/loginLog | Real Apple model, iOS version and OS hostname appear in saved six-header audit row | Pending real iPhone/backend |
| Network/log fallback | Wi-Fi, cellular IPv4/IPv6 and unavailable echo; backend handles actual/empty metadata; no dummy IP | Pending real iPhone/backend |
| Cold start | Session revalidated; network failure remains retryable | Pending |
| Doctor summaries | Same period and data produce same values | Pending |
| Admin restricted/all access | Correct username filter and exact payment values | Pending |
| Current Week | Saturday through Friday, including month/year boundary | Pending |
| Background/resume | Access rechecked and stale dashboard data replaced | Pending |
| Switch account/centre | No prior account's summary remains on screen | Pending |
| Logout | Keychain active session removed; reopening does not restore it | Pending |
| iPad sizing (if supported) | Layout remains usable in all declared orientations | Pending |
| Camera/crop trial | Separate early platform trial, not implemented in M1 | Pending |
| Multipage prescription PDF trial | Separate early platform trial, not implemented in M1 | Pending |

**Acceptance decision:** Pending. This checklist is not evidence that these tests passed.

