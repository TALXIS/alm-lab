#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                              Lab sign-in                                               ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Signs you in to the three services the lab uses - GitHub (gh), Power Platform (txc) and
# Azure (az) - wherever a sign-in is missing, expired or doesn't match. Safe to re-run any
# time: when everything already works it only checks and reports. CP01 runs the same steps.
#
# Run it yourself, in your own terminal: signing in is always a person's decision. When a
# coding agent runs a checkpoint and a sign-in is needed, the checkpoint stops and the agent
# asks you to run this.
#
# Optional: set LAB_TENANT (tenant id or domain) to pin the training tenant for txc and az.
#
# Run:  .lab-scripts/lab-signin.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "Lab sign-in"
Invoke-LabSignIn
Write-Host "`nSigned in. Run .lab-scripts/lab-status.ps1 to see where you left off." -ForegroundColor Cyan
