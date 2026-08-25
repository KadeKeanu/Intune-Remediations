## Dell SupportAssist Removal

The detection script checks both 32-bit and 64-bit uninstall registry locations for Dell SupportAssist-related applications.

If SupportAssist is detected, Intune runs the remediation script. The remediation script attempts silent removal using the application's quiet uninstall command, MSI product code, or Dell's SupportAssist uninstaller.

Common successful MSI exit codes `0`, `1641`, and `3010` are accepted.

## Deployment flow

```text
Detection
   ↓
Issue found?
   ├── No → Exit 0 → No remediation
   └── Yes → Exit 1 → Run remediation
                         ↓
                    Success → Exit 0
                    Failure → Exit 1
```

## Important

Test these scripts with a pilot device group before broad production deployment.

The WinGet script only updates applications that WinGet can identify and for which an update is available from the configured sources.
