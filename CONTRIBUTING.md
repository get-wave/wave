# Contributing

Thanks for contributing to Wave.

This project is maintained as a personal-use native macOS app. Contributions should prioritize simple, reliable behavior and minimal UI/UX friction.

## Local Setup

1. Open `Wave.xcodeproj` in Xcode
2. Select scheme `Wave`
3. Press **Run** — this builds the Debug configuration, which installs as **Wave (Debug)** and uses bundle ID `io.monawwar.wave.debug`

> If you have the production Wave app installed, quit it first to avoid hotkey and audio tap conflicts.

## What To Focus On

- Dictation reliability (hotkey -> record -> transcribe -> paste)
- Lightweight native UX
- Safe single-instance behavior
- Clear onboarding and settings behavior

## Using AI To Build Features

AI-assisted contribution is welcome. If you use AI tools:

1. Keep prompts specific to this codebase and file paths.
2. Ask AI for incremental changes, not large rewrites.
3. Verify all generated code manually before committing.
4. Build and run the app after changes.
5. Confirm no regressions in:
   - global shortcut capture
   - overlay status behavior
   - text paste flow
   - onboarding/state persistence

When proposing AI-generated changes, include:
- what files changed
- what behavior changed
- how you validated locally

## PR/Change Notes

When submitting changes, keep notes concise:

- Problem being solved
- Implementation summary
- Validation steps run

## Installing a local build for testing

`make install-local` builds Release, installs it to `/Applications` and launches it. It signs the app with a local certificate named **Wave Local Dev**, so macOS keeps Accessibility and Microphone permissions across rebuilds. An ad-hoc signed build gets a new identity every time and loses them.

Create the certificate once:

```bash
cat > /tmp/wave-cert.cnf <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Wave Local Dev
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/wave.key -out /tmp/wave.pem -days 3650 -config /tmp/wave-cert.cnf
openssl pkcs12 -export -legacy -inkey /tmp/wave.key -in /tmp/wave.pem -name "Wave Local Dev" -out /tmp/wave.p12 -passout pass:wave
security import /tmp/wave.p12 -k ~/Library/Keychains/login.keychain-db -P wave -T /usr/bin/codesign
rm /tmp/wave.key /tmp/wave.p12
```

`security find-identity` lists it as "not trusted"; that's expected for a self-signed certificate and doesn't stop signing. After the first install, grant Accessibility once in System Settings. Later installs keep it.

