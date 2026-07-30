# Contributing to PIKA SH

## Adding a New Module

1. Create `Linux/Modules/your_module.sh`
2. Define the menu array and handler functions:

```bash
#!/usr/bin/env bash
set -e

YourMENU=(
    "item_key|i18n.title.key|i18n.desc.key|handler_function"
)

handler_function() {
    # Your implementation here
    pika_info "$(t 'your.status.key')"
}
```

3. Register the module in `Menu.sh` by adding a new entry to `MENU_MAIN` and a dispatch function.

## Adding a New Language

1. Copy `Linux/I18n/zh_CN.sh` as your template
2. Name it `Linux/I18n/<locale>.sh` (e.g., `ja_JP.sh`, `ko_KR.sh`)
3. Translate only the values (keys must match exactly)
4. The new locale will be auto-detected based on `$LANG` environment variable
5. Missing keys automatically fall back to `zh_CN`

## Adding a New Mirror

1. Edit `Linux/Lib/10-net.sh`
2. Add the URL to `PIKA_MIRRORS_DEFAULT` array
3. Deploy a `.pika-healthz` file at the mirror root
4. The probe file must contain the string `PIKA_SH_OK`

## Adding a New Benchmark

1. Place the upstream script on the `assets` branch
2. Create a thin wrapper in `Linux/VPSTest/your-bench.sh`
3. Register in `Linux/Modules/bench.sh` `BenchMENU` array

## Code Style

- Shell scripts: `#!/usr/bin/env bash` with `set -e`
- Use `pika_info`/`pika_warn`/`pika_err` for output (never `echo` directly)
- Use `t "key"` for all user-visible strings (i18n)
- Use `pika_fetch` for all downloads
- Use `pkg_install` for all package installations
- Use `svc_register` for all service registrations

## Testing

Run ShellCheck before committing:
```bash
shellcheck Linux/**/*.sh
```

Test on at least two distributions:
- Debian 12 / Ubuntu 24.04
- AlmaLinux 9 / Alpine Linux
