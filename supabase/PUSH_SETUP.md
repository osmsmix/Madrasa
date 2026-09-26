# Push notifications — setup (mobile-first)

The code is ready on both sides:
- **Client:** `lib/services/push_service.dart` registers the device token into `devices`
  and shows notifications. It **no-ops until Firebase is configured**, so the app
  keeps running on web without it.
- **Server:** `supabase/functions/send-push/index.ts` sends FCM v1 notifications for
  three events: new grade, absence/late, and announcement.

Do these steps once.

## 1. Create the Firebase project + configure the app (mobile)
1. In the [Firebase console](https://console.firebase.google.com), create a project
   for Madrasa. Add an **Android app** (package `com.example.madrasa` — check
   `android/app/build.gradle` for the real `applicationId`) and, if targeting iOS,
   an **iOS app** (its bundle id).
2. Install the CLI and configure:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart`, adds `android/app/google-services.json`
   (and the iOS plist), and wires the Gradle plugin. `PushService` calls
   `Firebase.initializeApp()` which picks these up automatically — no code change needed.
3. Rebuild the app on a device/emulator (`flutter run`). Grant the notification
   permission when prompted. The token is saved to `devices` after sign-in.

> iOS also needs an APNs key uploaded in Firebase (Project settings → Cloud Messaging).

## 2. Service account for the server
1. Firebase console → **Project settings → Service accounts → Generate new private key**.
   You get a JSON file.
2. Set it (and an optional shared secret) as Supabase secrets:
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat path/to/serviceAccount.json)"
   supabase secrets set WEBHOOK_SECRET="<any-random-string>"
   ```

## 3. Deploy the function
```bash
supabase functions deploy send-push --no-verify-jwt
```
(`--no-verify-jwt` because database webhooks call it directly, not with a user JWT;
the `WEBHOOK_SECRET` header is the guard instead.)

## 4. Wire the database webhooks
In the Supabase dashboard → **Database → Webhooks → Create**, add **three** webhooks,
all pointing at the `send-push` Edge Function, HTTP POST, with an HTTP header
`x-webhook-secret: <the WEBHOOK_SECRET you set>`:

| Table | Events |
|-------|--------|
| `grades` | Insert, Update |
| `attendance` | Insert, Update |
| `announcements` | Insert |

The function reads the webhook payload (`{ type, table, record, old_record }`) and
figures out the recipients:
- **grades** → the student's parents (by phone).
- **attendance** → the student's parents, only when status is `absent`/`late` and it's
  a new mark or an actual status change (parent excuse edits don't re-notify).
- **announcements** → teachers and/or parents per the announcement's audience (and class).

## Notes
- **Web push** is not set up (mobile-first). Adding it later means a VAPID key + a
  service worker; the same `send-push` function serves both once web tokens register.
- Recipients are matched via `profiles.phone` (parents) and `memberships.user_id`
  (teachers) → `devices.fcm_token`. A user only receives push once they've signed in
  on a device (so their token exists).
- Notification text is currently in French; per-recipient localization (using
  `profiles.preferred_lang`) can be added later.
