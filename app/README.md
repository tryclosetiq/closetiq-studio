# ClosetIQ Studio (Flutter)

Phase 1 foundation for the public multi-creator Studio. One Flutter codebase targets iOS and web. The logged-in tool lives here. The public shopper page is the plain HTML app in `../storefront/`, so `/@handle` stays a normal web page.

The live single-user site on `main` (`index.html` and `shop.html`) is unchanged. Do not point this app at that production Supabase project.

## Run the example studio

No keys required. The sign-in screen has **Preview with example content**, or start there directly:

```bash
flutter run -d chrome --dart-define=STUDIO_PREVIEW=true
```

Example content is Heather's studio (handle `heather`). It is in-memory only.

## Connect a new Supabase project

Create a **new** project. Apply the SQL files in `../supabase/migrations/` there, and deploy `import-product` and `go` from `../supabase/functions/`. Copy `dart_defines.example.json` to `dart_defines.json` (gitignored) and fill in that project's URL and anon key:

```bash
flutter run -d chrome --dart-define-from-file=dart_defines.json
flutter build web --dart-define-from-file=dart_defines.json
flutter build ipa --dart-define-from-file=dart_defines.json
```

| Define | Purpose |
| --- | --- |
| `SUPABASE_URL` | New project URL, `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | That project's anon (publishable) key |
| `STOREFRONT_ORIGIN` | Public origin for copy-link and QR, default `https://closetiq.app` |
| `AUTH_REDIRECT` | Optional web redirect after email links and OAuth |
| `CLOSETIQ_APP_STORE_URL` | Optional link behind **Get the app** |
| `STUDIO_PREVIEW` | `true` opens the example studio and skips sign-in |

Placeholder values (`YOUR_PROJECT`, `YOUR_ANON`) leave the app on the sign-in screen. Nothing is sent until both values are real.

## What Heather sets up before accounts work

1. New Supabase project. Do not link, push, or paste keys from the existing production project.
2. Run the four migration files, in filename order, on that new project only. They create profiles, per-creator settings, a read-only credit balance, closet tables, look sync, click tracking, storage policies, and in-app account deletion.
3. Authentication → enable Email, Google, and Apple. Add redirect URLs for the web app (and `AUTH_REDIRECT` if you set one). Apple needs a Services ID whose redirect is `https://<ref>.supabase.co/auth/v1/callback`.
4. Deploy `import-product` with JWT verification on, and `go` with JWT verification off (`supabase/config.toml` already says this).
5. Host `../storefront/` with the rewrites in `vercel.json` / `_redirects`. Copy `config.example.js` to `config.js` with the same new anon key. `config.js` is gitignored.
6. Apple Developer: App ID `com.closetiq.studio`, Sign in with Apple capability. The Xcode project does not include the entitlement yet; turn the capability on when you open `ios/Runner.xcworkspace` on a Mac. Photo library usage text is already in `Info.plist`.
7. iOS archive requires macOS and Xcode. This repo's Linux checks build the web target only.

Account deletion calls `delete_own_account`. It removes the creator's files under their user-id folder in the `studio` and `shop` buckets, then deletes the auth user. There is no subscription to cancel in this phase.

## Checks

```bash
flutter analyze
flutter test
```

From the repo root:

```bash
node --test supabase/functions/_shared/product_meta.test.js supabase/tests/contract.test.js
```

Manual pass, preview mode is enough for the shell:

- Home shows the idea card, 7-day clicks, up next, and recent looks. The chart opens Insights. The person icon opens Account.
- Phone tabs: Home, Closet, raised Create, Storefront, Schedule. At width 900 and up, those plus Insights sit in the left sidebar.
- Create walks Idea → Pick pieces → Try it on → Make & share. The share sheet keeps **Share to ClosetIQ** locked, with **Get the app**. Schedule saves a reminder only.
- Closet → Add item. Paste an https link (needs `import-product`) or fill the form. Leave the affiliate link blank and the item is not monetized.
- Storefront copies `https://closetiq.app/@heather` and shows a QR code. Hiding a piece keeps it on the outfit.
- Account → Delete account asks you to type DELETE, then returns to sign-in. Sign-in offers Google, Apple, and the example preview.

## Later, not in this phase

Billing, credit purchases, FASHN try-on, auto captions, Discover, link-health checks, Amazon upload-pack export, and any social auto-post. Schedule rows are reminders. The iOS app does not store social tokens.
