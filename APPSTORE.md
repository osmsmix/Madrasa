# App Store submission checklist — Madrasa

Goal: submit to the App Store ASAP and request **expedited review** to land before
the interview. You've shipped apps before, so this focuses on the Madrasa-specifics.

## 0. Code/config changes (done in the repo)
- iOS deployment target → **15.0** (Firebase requires it). ✅
- Display name → **Madrasa**. ✅
- **Reviewer login** bypass in `send-otp` / `verify-otp` (fixed test phone + code). ✅
- **In-app account deletion** (account menu → Delete account) + `delete-account` function. ✅

## 1. Change the bundle identifier
It's still the placeholder `com.example.madrasa`. In Xcode → Runner target → Signing
& Capabilities, set your real bundle id (e.g. `com.<yourteam>.madrasa`) and your team.
Do the same `applicationId` in `android/app/build.gradle.kts` later for Play.

## 2. Deploy the backend
```bash
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase functions deploy delete-account
supabase secrets set TEST_PHONE=22200000000
supabase secrets set TEST_OTP=123456
```
Then run **`supabase/demo_seed.sql`** in the SQL editor (set `v_phone` = `22200000000`
in each block). This creates three populated demo schools — the test phone is
Director of one, Teacher in another, and Parent in the third.

> The demo login works even with no WhatsApp/SMS: `send-otp` and `verify-otp` skip the
> provider for `TEST_PHONE` and accept `TEST_OTP`.

## 3. Build & upload
`flutter build ipa` (or archive in Xcode) → upload to App Store Connect. App icon is
already set. Take **screenshots** on a 6.7" and a 6.5" iPhone simulator (login, the
"choose school & role" screen, director dashboard, teacher attendance, parent grades).

## 4. App Store Connect metadata
- **Name:** Madrasa
- **Subtitle:** Gestion scolaire & suivi des parents
- **Category:** Education
- **Age rating:** 4+
- **Privacy Policy URL:** host `PRIVACY.md` somewhere public (GitHub Pages, your site,
  or a free host) and paste the URL.
- **Support URL:** any page/email you control.
- **Keywords:** `école,notes,présence,bulletin,parents,enseignant,scolaire,madrasa,education`
- **Description (FR):**
  > Madrasa est une application de gestion scolaire et de communication avec les
  > parents. Le directeur configure son école (classes, matières, enseignants,
  > emploi du temps, élèves). Les enseignants saisissent les présences et les notes
  > en temps réel. Les parents consultent instantanément, depuis leur téléphone, les
  > notes et les absences de leurs enfants, et peuvent justifier une absence.
  >
  > • Directeur : classes, matières, enseignants, emploi du temps, élèves, annonces
  > • Enseignant : emploi du temps du jour, présences, évaluations et notes
  > • Parent : notes et présences de chaque enfant, justification des absences
  > • Disponible en arabe (droite à gauche), français et anglais
  > • Connexion simple par numéro de téléphone
- **Description (EN):** same, translated.

## 5. App Review notes (paste this in "Notes for Reviewer")
> This app signs in with a phone number and a one-time code. Use this demo account:
>
> **Phone:** the login screen shows a **+222** prefix — just type **`00000000`** (eight zeros)
> **Verification code:** `123456`
>
> After signing in, the "Choose school and role" screen lists three schools:
> you are **Director** of *Lycée El Nour*, **Teacher** at *Collège Avenir*, and
> **Parent** at *École La Paix*. Open any one to explore that role (each has data).
> Account deletion is available from the account icon (top-right) → **Delete account**.

## 6. Notes on Apple guidelines (why we should pass)
- **Sign in with Apple is NOT required** — phone-number OTP is a first-party login,
  not a third-party social login, so 4.8 doesn't apply.
- **Account deletion (5.1.1(v))** — provided in-app. ✅
- **Login required (2.1)** — a working demo account is provided above. ✅
- **Privacy (5.1.1)** — privacy policy provided; complete the App Privacy
  "data collected" questionnaire (Phone number → App functionality; not used for
  tracking).

## 7. Submit + expedite
After submitting for review, request expedited review here:
https://developer.apple.com/contact/app-store/?topic=expedite — explain it's for a
time-sensitive investor/accelerator interview.

## Push notifications (optional for v1)
Push is coded but needs Firebase (not required to ship). Fine to submit **without**
push and add it in an update. If you keep the Firebase pods in this build, no push
capability/entitlement is declared, so it won't affect review.
