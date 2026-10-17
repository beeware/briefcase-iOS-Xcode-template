"""Run in UIApplicationMain, without a nested run loop or heartbeat."""

import threading
import time

from rubicon.objc import ObjCClass, objc_method
from rubicon.objc.eventloop import CFLifecycle, RubiconEventLoop


class NativeLifecycle(CFLifecycle):
    def start(self):
        # UIApplicationMain starts the outer run loop after this module returns.
        pass


loop = RubiconEventLoop()
result = None


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
        print(f"Worker and callback completed after {elapsed:.3f}s", flush=True)
        finish(0 if elapsed < 1 else 1)

    def worker():
        time.sleep(0.1)
        loop.call_soon_threadsafe(delivered)

    # There are no intervening main-thread timers to release the GIL by accident.
    loop.call_later(3, finish, 1)
    threading.Thread(target=worker, daemon=True).start()


class PythonAppDelegate(ObjCClass("UIResponder")):
    @objc_method
    def application_didFinishLaunchingWithOptions_(
        self, application, launch_options
    ) -> bool:
        loop.call_later(0.1, start_probe)
        return True


loop.run_forever_cooperatively(lifecycle=NativeLifecycle())
