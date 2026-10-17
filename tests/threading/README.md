# Native launcher threading regression

This application returns from Python into `UIApplicationMain`, then starts a Python worker while UIKit is otherwise idle. The worker sleeps for 0.1 seconds and schedules a callback on the main thread. The test fails if the worker and callback cannot complete within one second. A three-second watchdog bounds a failure; there is no heartbeat before the verdict.

By default, the test uses released Rubicon 0.5.7 with a lifecycle that does not nest a run loop. It checks that the launcher exposes `sys._ios_app_main_releases_gil = True` before importing application code and actually releases the GIL while UIKit runs. The old launcher fails this test.

From this directory, with Briefcase installed and an iOS Simulator available:

```console
briefcase run iOS --test --no-input -C 'template="../.."'
```

Use a fresh generated application after changing the template. Briefcase's `--update` option updates Python application code; it does not regenerate `main.m`. Use `-d <simulator-UDID>` to select a simulator.

## Partial-upgrade compatibility

`--lifecycle default` exercises the unmodified `iOSLifecycle()` constructor used by Toga. The test observes whether the real lifecycle start call returns, checks the advertised capability, and verifies prompt worker delivery on the main thread.

Run each of these combinations, using Rubicon 0.5.7 for the old version and a wheel from the companion Rubicon PR for the new version:

| Rubicon | Launcher | `--expect-nested` | `--expect-capability` |
| --- | --- | --- | --- |
| Old | Old | `yes` | `no` |
| Old | New | `yes` | `yes` |
| New | Old | `yes` | `no` |
| New | New | `no` | `yes` |

For example, with a fresh project generated from the new launcher and a local new Rubicon wheel:

```console
briefcase run iOS --test --no-input -r -C 'template="../.."' -C 'requires=["rubicon-objc @ file:///absolute/path/to/rubicon.whl"]' -- --lifecycle default --expect-nested no --expect-capability yes
```

Replace the template path with a checkout of the old template for old-launcher cases. Replace the requirement with `rubicon-objc==0.5.7` for old-Rubicon cases. Keep the same test source in all four runs. Changing only the Rubicon requirement can reuse a generated project with `-r`; changing the native launcher requires regenerating and rebuilding it.

All four combinations must deliver callbacks promptly. Only new Rubicon with the new launcher should avoid nesting. No Toga change or application-level capability assignment is involved.
