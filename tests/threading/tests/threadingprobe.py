"""Check worker delivery and lifecycle selection under a real UIKit host."""

import argparse
import json
import sys
import threading
import time
from importlib.metadata import version

from rubicon.objc import ObjCClass, objc_method
from rubicon.objc.eventloop import CFLifecycle, RubiconEventLoop, iOSLifecycle


class NativeLifecycle(CFLifecycle):
    def start(self):
        # UIApplicationMain starts the outer run loop after this module returns.
        pass


parser = argparse.ArgumentParser()
parser.add_argument("--lifecycle", choices=["native", "default"], default="native")
parser.add_argument("--expect-nested", choices=["yes", "no"], default="no")
parser.add_argument("--expect-capability", choices=["yes", "no"], default="yes")
args = parser.parse_args()

# Capture the launcher's flag before the app has a chance to change it.
capability = getattr(sys, "_ios_app_main_releases_gil", None)
main_thread = threading.get_ident()
loop = RubiconEventLoop()
result = None
lifecycle_started = False
lifecycle_returned = False
lifecycle = iOSLifecycle() if args.lifecycle == "default" else NativeLifecycle()
original_start = lifecycle.start


def observed_start():
    global lifecycle_started, lifecycle_returned
    lifecycle_started = True
    original_start()
    lifecycle_returned = True


# Observe the real start call: a nested NSRunLoop does not return during the test.
# Do not override the constructor arguments or the launcher's capability flag.
lifecycle.start = observed_start


def report():
    print(f">>>>>>>>>> EXIT {result} <<<<<<<<<<", flush=True)
    # Repeat only after the verdict, so logging startup cannot lose the result.
    loop.call_later(1, report)


def finish(returncode):
    global result
    if result is None:
        result = returncode
        report()


def start_probe():
    started = time.monotonic()

    def delivered():
        elapsed = time.monotonic() - started
        nested = not lifecycle_returned
        passed = (
            lifecycle_started
            and elapsed < 1
            and threading.get_ident() == main_thread
            and nested == (args.expect_nested == "yes")
            and (capability is True) == (args.expect_capability == "yes")
        )
        print(
            json.dumps({
                "rubicon": version("rubicon-objc"),
                "capability": capability,
                "nested": nested,
                "elapsed": elapsed,
                "passed": passed,
            }),
            flush=True,
        )
        finish(0 if passed else 1)

    def watchdog():
        print("Worker callback did not complete before the watchdog", flush=True)
        finish(1)

    def worker():
        time.sleep(0.1)
        loop.call_soon_threadsafe(delivered)

    # There are no intervening main-thread timers to release the GIL by accident.
    loop.call_later(3, watchdog)
    threading.Thread(target=worker, daemon=True).start()


class PythonAppDelegate(ObjCClass("UIResponder")):
    @objc_method
    def application_didFinishLaunchingWithOptions_(
        self, application, launch_options
    ) -> bool:
        loop.call_later(0.1, start_probe)
        return True


loop.run_forever_cooperatively(lifecycle=lifecycle)
