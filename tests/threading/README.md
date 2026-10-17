# Native launcher threading regression

This application returns from Python into `UIApplicationMain`, then starts a Python worker while UIKit is otherwise idle. The worker sleeps for 0.1 seconds and schedules a callback on the main thread. The test fails if the worker and callback cannot complete within one second. A three-second watchdog bounds a failure; there is no heartbeat before the verdict.

With the old launcher, `UIApplicationMain` keeps the GIL and the worker cannot resume until the watchdog fires. With the corrected launcher, both the worker and its callback complete promptly. The test uses released Rubicon 0.5.7 and a lifecycle that does not nest a run loop, so it isolates the native launcher change.

From this directory, with Briefcase installed and an iOS Simulator available:

```console
briefcase run iOS --test --no-input -C 'template="../.."'
```

Use a fresh generated application after changing the template. Briefcase's `--update` option updates Python application code; it does not regenerate `main.m`. Use `-d <simulator-UDID>` to select a simulator.
