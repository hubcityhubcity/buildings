# Android-Only MT5 Workflow

## Core constraint

The trader currently has no working laptop. Every setup step must be possible from an Android phone.

The solution is to use a Windows VPS as the cloud computer. The Android phone connects to that VPS through a remote desktop app. MT5, MetaEditor, the Expert Advisor, and the demo account all live on the VPS.

## Practical architecture

```text
Android phone
   -> remote desktop app
      -> Windows VPS
         -> MT5 terminal
            -> FortressFX Expert Advisor
               -> demo account first
               -> FTMO challenge only after rehearsal passes
```

## What the phone does

- Rent/manage the VPS through a browser.
- Connect to the VPS through remote desktop.
- Open MT5 and MetaEditor on the VPS.
- Copy/paste EA code from GitHub if needed.
- Monitor email alerts.
- Restart MT5 or the VPS when needed.

## What the VPS does

- Runs Windows 24/5.
- Runs MT5 continuously.
- Hosts the FortressFX EA.
- Keeps the trading terminal online while the trader sleeps or works.
- Stores MT5 logs and strategy tester reports.

## Phone-only setup sequence

1. Choose a Windows VPS provider.
2. Buy a Windows VPS with enough resources for MT5.
3. Save the VPS IP address, username, and password in a password manager.
4. Install a remote desktop app on Android.
5. Connect to the VPS from the phone.
6. Use the VPS browser to install MT5.
7. Log into an MT5 demo account.
8. Open MetaEditor on the VPS.
9. Add `FortressFX.mq5` into the `Experts` folder.
10. Compile the EA.
11. Attach it to one demo chart with `EXECUTION_ENABLED=false`.
12. Confirm logs.
13. Only then add strategy logic and test execution.

## VPS minimum target

For the first demo test:

- Windows Server or Windows 10/11 VPS
- 2 vCPU minimum
- 4 GB RAM preferred
- stable uptime
- ability to run MT5 continuously
- remote desktop access from Android

## Important safety notes

- Do not store broker passwords or FTMO credentials in screenshots.
- Do not use a public/free VPS for trading credentials.
- Keep `EXECUTION_ENABLED=false` until the EA compiles and logs cleanly.
- Start with one demo chart only.
- Do not pay for FTMO until the demo rehearsal gate passes.

## Immediate next action

The next user task is to choose a Windows VPS that can be operated from Android through remote desktop.
