# Reqnroll + Playwright BDD scaffold for Power Apps

This project is a generated scaffold for testing a Power Apps model-driven app with **Reqnroll**, **Playwright**, and **MSTest**.

## Prerequisites

- .NET 10 SDK (LTS)
- Playwright browser binaries — install with `pwsh bin/Debug/net10.0/playwright.ps1 install chromium` after the first `dotnet build`

## Project structure

- `Features/` - Gherkin scenarios
- `Support/Bindings/` - standardized model-driven app bindings
- `Support/` - hooks, configuration, and Xrm bridge helpers
- `Tests/` - offline reflection and helper tests

## Running tests

```bash
dotnet restore
dotnet test
dotnet test --list-tests
```

The sample feature is tagged `@live` and `@ignore` so offline runs stay green while still proving discovery and binding resolution.

## Configuration

Update `appsettings.json` or environment variables:

- `TXC_ENVIRONMENT_URL`
- `TXC_APP_NAME`
- `TXC_HEADLESS`
- `TXC_SLOWMO`
- `TXC_TIMEOUT`
- `TXC_STORAGE_STATE_PATH`
- `TXC_SCREENSHOT_ON_FAILURE`
- `TXC_TRACING_ENABLED`
- `TXC_OUTPUT_PATH`

## Signing in

`Given I am logged in as '<persona>'` does the signing in. There is no separate "capture auth"
command to run first and forget: the step resolves the persona to an account, reuses a cached
session if there is one, and signs in through the Microsoft login page when there is not.

1. Copy `.env.example` to `.env` (gitignored) and fill in the account for each persona your
   feature files name. `'a warehouse manager'` reads `TXC_USER_WAREHOUSE_MANAGER_USERNAME` and
   `TXC_USER_WAREHOUSE_MANAGER_PASSWORD`; articles are dropped. `TXC_USER_USERNAME` /
   `TXC_USER_PASSWORD` cover every persona at once.
2. Run anything. The first scenario signs in and writes `.auth/state-<account>.json`; every
   scenario after it starts from that file and never sees a login page. When the session
   expires, the next scenario notices the redirect and signs in again.

Real environment variables beat `.env`, so CI passes the same names as secrets.

### MFA

Set `TXC_USER_<PERSONA>_OTP_SECRET` (or `TXC_USER_OTP_SECRET`) to the account's authenticator
seed — the base32 string beside the QR code — and the six-digit code is generated per run, so
headless works on an MFA-protected tenant. This is the same approach as
`UserConfiguration.OtpToken` in TALXIS.TestKit.

A seed is a second factor sitting in a file. Use one only for a test account that has no
standing access to anything, never for a person's account.

If MFA asks for something a seed cannot answer — a push approval, a phone call — do it once
with a browser you can see, and the cached session covers every headless run afterwards:

```bash
TXC_HEADLESS=false dotnet test --filter "TestCategory=auth"
```

### What is gitignored

`.env` and `.auth/`. A storage state is a live signed-in session; it leaks exactly as badly as
the password that produced it.

## Two-tier approach

1. Standard model-driven app surfaces use the frozen bindings in `Support/Bindings/`.
2. Non-standard UI belongs in custom step definitions outside the standardized binding set.

## Reporting

Artifacts are written to `{AppContext.BaseDirectory}/{OutputPath}` — by default this resolves to `bin/<config>/net10.0/TestResults/`.

To collect artifacts in a predictable project-relative directory, use:

```bash
dotnet test --results-directory ./TestResults
```

Default artifact layout inside the output directory:

- `screenshots/` — failure screenshots (when `ScreenshotOnFailure` is enabled)
- `traces/` — Playwright traces (when `TracingEnabled` is enabled)
