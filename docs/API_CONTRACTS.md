# First milestone API contracts

Source: `DocLogin.java`, selection dialogs and `DocDashboard.java` in the supplied baseline.
No endpoint was contacted from the creation environment. Runtime app calls use the configured
directory/base URLs, not the synthetic `.example` hosts used by tests.

| Method and relative route | Inputs | Response/use |
| --- | --- | --- |
| GET `login/getAllLoginData` | query `doc_code`, `doc_password` | `is_available`, `is_online`, `p_center_api`, `p_center_name`, `p_doc_code`, `p_admin_user_flag`, `p_admin_user_id`, lists |
| POST `login/updateFLFlag` | header `P_DOC_CODE` | exact `string_out = Successfully Created` required |
| POST `login/updateAdminFLFlag` | header `P_USR_ID` | same success contract |
| GET `doc_dashboard/getDocData` | query `doc_code` | `items` doctor identity, permissions, access/expiry fields |
| GET `doc_dashboard/getAdminData` | query `p_usr_id` | `items` admin identity, permissions, access/expiry fields |
| POST `doc_dashboard/updateDocExpDate` | headers `P_DATE`, `P_DOC_CODE` | first-login expiry initialization |
| POST `doc_dashboard/updateUSRExpDate` | headers `P_DATE`, `P_USR_ID` | admin first-login expiry initialization |
| POST `doc_dashboard/loginLog` | six `P_IULL_*` headers from native contract | initialization audit; iOS device descriptor replaces Android descriptor |
| GET `doc_dashboard/getDocFLFlag` | query `p_doc_id` | forced logout recheck |
| GET `doc_dashboard/getAdminFLFlag` | query `p_usr_id` | admin forced logout recheck |
| GET `doc_dashboard/getMeetingCount` | query `doc_id`, `first_date`, `end_date` | appointment rows/count; elapsed-time completed/remaining |
| GET `doc_dashboard/getScheduleCount` | same query | `schedule`, `block_schedule` |
| GET `doc_dashboard/getMeetingSchedule` | query `doc_id`, `time_now` | `last_sc`, `next_sc`, `pat_name`; next meeting text is ported |
| GET `doc_dashboard/getAdminAppPayCountNew` | query `begin_date`, `end_date`, `user_id` | `total_app_count`, `cancel_app_count`, `total_pay_rcv`, `total_pay_rtn` |

## Discovery variants

| `is_available` | Meaning |
| --- | --- |
| `0` | Rejected login; present `is_online` message when provided |
| `1` | Direct doctor/admin account, determined by `p_admin_user_flag` (`1` / `2`) |
| `3` | Doctor account list |
| `4` | Admin account list |
| `5` | Mixed admin and doctor lists, admins listed first as in native source |

Native arrays may be arrays or JSON-encoded strings. JSON null and literal `"null"`
are normalized where the Android implementation uses fallback values.

Credentials never appear in application logging. The underlying legacy authentication
contract still sends them in a query; changing that requires a separate backend agreement.


## iOS loginLog client descriptor (18 October 2026)

The existing six-header POST now uses DeviceInfoPlugin utsname.machine,
Apple brand, actual systemName/systemVersion, Platform.localHostname and
Wi-Fi/public/local-interface IP fallback. There is no additional login POST.
No dummy host/IP is written. Missing optional metadata stays empty; backend
acceptance of empty fields and IPv6 needs live testing. Source IP observed by
the backend is a distinct server-side fact. See STARTUP_DEVICE_UPDATE_BN.md.

Separate public reads: Apple HTTPS lookup by actual bundle ID/optional numeric
Apple ID and country; HTTPS public-IP echo only without usable Wi-Fi. Neither
request carries DocDiary identity/custom login headers. The default public echo
can be disabled or replaced with a first-party HTTPS JSON endpoint.
