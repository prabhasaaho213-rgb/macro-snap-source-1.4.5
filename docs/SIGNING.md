# APK Signing & Google Sign-In

## Why This Matters

Google Sign-In verifies the APK's **signing certificate SHA-1** against what's
registered in Firebase Console. If the SHA-1 doesn't match, Sign-In fails with
error code 10 (DEVELOPER_ERROR).

## Registered SHA-1 Fingerprints (Firebase Console)

| Type | SHA-1 | Keystore |
|------|-------|----------|
| Release | `07:ED:F9:11:70:5A:C0:A8:96:FB:66:9E:20:4D:A8:D6:E9:6E:F8:4D` | `upload-keystore.jks` |
| Debug | `B6:62:15:9F:BD:0E:21:E4:DB:73:5B:F4:43:7A:81:EA:12:3D:20:36` | `~/.android/debug.keystore` |

## How It Works

1. **CI builds** always sign with `upload-keystore.jks` (the release keystore)
2. **Local builds** may use the debug keystore — both SHA-1s are registered
3. **GitHub Actions** uses secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, etc.)

## If You Change the Keystore

1. Get the new SHA-1: `keytool -list -v -keystore your-new.jks -alias upload`
2. Add it to Firebase Console: Project Settings → Android app → Add fingerprint
3. Update GitHub secrets if needed: `gh secret set KEYSTORE_BASE64 --body "..."`

## GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `KEYSTORE_BASE64` | Base64-encoded `upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Key alias (usually `upload`) |

## Troubleshooting

### Google Sign-In fails with error 10

1. Check the APK's SHA-1: `keytool -list -v -keystore app.jks -alias upload | grep SHA1`
2. Compare with Firebase Console's registered SHA-1s
3. If missing, add it to Firebase Console

### APK built with wrong keystore

The CI workflow has a verification step that checks the keystore exists.
If it fails, check:
- GitHub secrets are set correctly
- `key.properties` points to the right file
- The keystore file wasn't corrupted during base64 encoding
