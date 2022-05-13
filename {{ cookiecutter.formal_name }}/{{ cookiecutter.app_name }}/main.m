//
//  main.m
//  A main module for starting Python projects under iOS.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <Python.h>
#include <dlfcn.h>


void crash_dialog(NSString *);
NSString * format_traceback(PyObject *type, PyObject *value, PyObject *traceback);

int main(int argc, char *argv[]) {
    int ret = 0;
    unsigned int i;
    NSString *tmp_path;
    NSString *python_home;
    NSString *python_path;
    NSString *traceback_str;
    wchar_t *wpython_home;
    const char* nslog_script;
    wchar_t** python_argv;
    PyObject *module;
    PyObject *runpy;
    PyObject *runmodule;
    PyObject *runargs;
    PyObject *result;
    PyObject *exc_type;
    PyObject *exc_value;
    PyObject *exc_traceback;
    PyObject *systemExit_code;

    @autoreleasepool {

        NSString * resourcePath = [[NSBundle mainBundle] resourcePath];

        // Special environment to prefer .pyo; also, don't write bytecode
        // because the process will not have write permissions on the device.
        putenv("PYTHONOPTIMIZE=1");
        putenv("PYTHONDONTWRITEBYTECODE=1");
        putenv("PYTHONUNBUFFERED=1");

        // Set the home for the Python interpreter
        python_home = [NSString stringWithFormat:@"%@/Library/Python", resourcePath, nil];
        NSLog(@"PythonHome is: %@", python_home);
        wpython_home = Py_DecodeLocale([python_home UTF8String], NULL);
        Py_SetPythonHome(wpython_home);

        // Set the PYTHONPATH
        python_path = [NSString stringWithFormat:@"PYTHONPATH=%@/Library/Application Support/{{ cookiecutter.bundle }}.{{ cookiecutter.app_name }}/app:%@/Library/Application Support/{{ cookiecutter.bundle }}.{{ cookiecutter.app_name }}/app_packages", resourcePath, resourcePath, nil];
        NSLog(@"PYTHONPATH is: %@", python_path);
        putenv((char *)[python_path UTF8String]);

        // iOS provides a specific directory for temp files.
        tmp_path = [NSString stringWithFormat:@"TMP=%@/tmp", resourcePath, nil];
        putenv((char *)[tmp_path UTF8String]);

        NSLog(@"Initializing Python runtime...");
        Py_Initialize();

        // Set the name of the python NSLog bootstrap script
        nslog_script = [
            [[NSBundle mainBundle] pathForResource:@"Library/Application Support/{{ cookiecutter.bundle }}.{{ cookiecutter.app_name }}/app_packages/nslog"
                                            ofType:@"py"] cStringUsingEncoding:NSUTF8StringEncoding];

        if (nslog_script == NULL) {
            NSLog(@"Unable to locate NSLog bootstrap script.");
        }

        // Construct argv for the interpreter
        python_argv = PyMem_RawMalloc(sizeof(wchar_t*) * argc);

        python_argv[0] = Py_DecodeLocale("{{ cookiecutter.module_name }}", NULL);
        for (i = 1; i < argc; i++) {
            python_argv[i] = Py_DecodeLocale(argv[i], NULL);
        }

        PySys_SetArgv(argc, python_argv);

        @try {
            if (nslog_script == NULL) {
                NSLog(@"No Python NSLog handler found. stdout/stderr will not be captured.");
                NSLog(@"To capture stdout/stderr, add 'std-nslog' to your app dependencies.");
            } else {
                NSLog(@"Installing Python NSLog handler...");
                FILE* fd = fopen(nslog_script, "r");
                if (fd == NULL) {
                    NSLog(@"Unable to open nslog.py; abort.");
                    exit(-1);
                }

                ret = PyRun_SimpleFileEx(fd, nslog_script, 1);
                fclose(fd);
                if (ret != 0) {
                    NSLog(@"Unable to install Python NSLog handler; abort.");
                    exit(ret);
                }
            }

            // Start the app module
            NSLog(@"Running '{{ cookiecutter.module_name }}'...");
            runpy = PyImport_ImportModule("runpy");
            if (runpy == NULL) {
                NSLog(@"Could not import runpy module");
                exit(-2);
            }

            runmodule = PyObject_GetAttrString(runpy, "_run_module_as_main");
            if (runmodule == NULL) {
                NSLog(@"Could not access runpy._run_module_as_main");
                exit(-3);
            }

            module = PyUnicode_FromWideChar(python_argv[0], wcslen(python_argv[0]));
            if (module == NULL) {
                NSLog(@"Could not convert module name to unicode");
                exit(-3);
            }

            runargs = Py_BuildValue("(Oi)", module, 0);
            if (runargs == NULL) {
                NSLog(@"Could not create arguments for runpy._run_module_as_main");
                exit(-4);
            }

            result = PyObject_Call(runmodule, runargs, NULL);
            if (result == NULL) {
                // Retrieve the current error state of the interpreter.
                PyErr_Fetch(&exc_type, &exc_value, &exc_traceback);
                PyErr_NormalizeException(&exc_type, &exc_value, &exc_traceback);

                if (exc_traceback == NULL) {
                    NSLog(@"Could not retrieve traceback");
                    crash_dialog(@"Could not retrieve traceback");
                    exit(-5);
                }

                if (PyErr_GivenExceptionMatches(exc_value, PyExc_SystemExit)) {
                    systemExit_code = PyObject_GetAttrString(exc_value, "code");
                    if (systemExit_code == NULL) {
                        NSLog(@"Could not determine exit code");
                        ret = -10;
                    }
                    else {
                        ret = (int) PyLong_AsLong(systemExit_code);
                    }
                } else {
                    ret = -6;
                }

                if (ret != 0) {
                    NSLog(@"Application quit abnormally (Exit code %d)!", ret);

                    traceback_str = format_traceback(exc_type, exc_value, exc_traceback);

                    // Restore the error state of the interpreter.
                    PyErr_Restore(exc_type, exc_value, exc_traceback);

                    // Print exception to stderr.
                    // In case of SystemExit, this will call exit()
                    PyErr_Print();

                    // Display stack trace in the crash dialog.
                    crash_dialog(traceback_str);
                    exit(ret);
                }
            } else {
                // In a normal iOS application, the following line is what
                // actually runs the application. It requires that the
                // Objective-C runtime environment has a class named
                // "PythonAppDelegate". This project doesn't define
                // one, because Objective-C bridging isn't something
                // Python does out of the box. You'll need to use
                // a library like Rubicon-ObjC [1], Pyobjus [2] or
                // PyObjC [3] if you want to run an *actual* iOS app.
                // [1] http://beeware.org/rubicon
                // [2] http://pyobjus.readthedocs.org/
                // [3] https://pythonhosted.org/pyobjc/
                UIApplicationMain(argc, argv, nil, @"PythonAppDelegate");
            }
        }
        @catch (NSException *exception) {
            NSLog(@"Python runtime error: %@", [exception reason]);
            crash_dialog([NSString stringWithFormat:@"Python runtime error: %@", [exception reason]]);
            ret = -7;
        }
        @finally {
            Py_Finalize();
        }

        PyMem_RawFree(wpython_home);
        if (python_argv) {
            for (i = 0; i < argc; i++) {
                PyMem_RawFree(python_argv[i]);
            }
            PyMem_RawFree(python_argv);
        }
    }

    exit(ret);
    return ret;
}

/**
 * Construct and display a modal dialog to the user that contains
 * details of an error during application execution (usually a traceback).
 */
void crash_dialog(NSString *details) {
    NSLog(@"Application has crashed!");
    NSLog(@"========================\n%@", details);

    // TODO - acutally make this a dialog
    NSString *full_message = [NSString stringWithFormat:@"An unexpected error occurred.\n%@", details];
    // Create a stack trace dialog
    [UIAlertController alertControllerWithTitle:@"Application has crashed"
                                        message:full_message
                                 preferredStyle:UIAlertControllerStyleAlert];

}

/**
 * Convert a Python traceback object into a user-suitable string, stripping off
 * stack context that comes from this stub binary.
 *
 * If any error occurs processing the traceback, the error message returned
 * will describe the mode of failure.
 */
NSString *format_traceback(PyObject *type, PyObject *value, PyObject *traceback) {
    NSRegularExpression *regex;
    NSString *traceback_str;
    PyObject *traceback_list;
    PyObject *traceback_module;
    PyObject *format_exception;
    PyObject *traceback_unicode;
    PyObject *inner_traceback;

    // Drop the top two stack frames; these are internal
    // wrapper logic, and not in the control of the user.
    for (int i = 0; i < 2; i++) {
        inner_traceback = PyObject_GetAttrString(traceback, "tb_next");
        if (inner_traceback != NULL) {
            traceback = inner_traceback;
        }
    }

    // Format the traceback.
    traceback_module = PyImport_ImportModule("traceback");
    if (traceback_module == NULL) {
        NSLog(@"Could not import traceback");
        return @"Could not import traceback";
    }

    format_exception = PyObject_GetAttrString(traceback_module, "format_exception");
    if (format_exception && PyCallable_Check(format_exception)) {
        traceback_list = PyObject_CallFunctionObjArgs(format_exception, type, value, traceback, NULL);
    } else {
        NSLog(@"Could not find 'format_exception' in 'traceback' module");
        return @"Could not find 'format_exception' in 'traceback' module";
    }
    if (traceback_list == NULL) {
        NSLog(@"Could not format traceback");
        return @"Could not format traceback";
    }

    traceback_unicode = PyUnicode_Join(PyUnicode_FromString(""), traceback_list);
    traceback_str = [NSString stringWithUTF8String:PyUnicode_AsUTF8(PyObject_Str(traceback_unicode))];

    // Take the opportunity to clean up the source path,
    // so paths only refer to the "app local" path.
    regex = [NSRegularExpression regularExpressionWithPattern:@"^  File \"/.*/(.*?).app/Library"
                                                      options:NSRegularExpressionAnchorsMatchLines
                                                        error:nil];
    traceback_str = [regex stringByReplacingMatchesInString:traceback_str
                                                    options:0
                                                      range:NSMakeRange(0, [traceback_str length])
                                               withTemplate:@"  File \"$1.app/Library"];

    return traceback_str;
}
