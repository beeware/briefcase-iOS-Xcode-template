//
//  main.m
//  A main module for starting Python projects under iOS.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <Python/Python.h>
#include <dlfcn.h>


void crash_dialog(NSString *);
NSString * format_traceback(PyObject *type, PyObject *value, PyObject *traceback);

int main(int argc, char *argv[]) {
    int ret = 0;
    PyStatus status;
    PyPreConfig preconfig;
    PyConfig config;
    NSString *python_home;
    NSString *app_module_name;
    NSString *path;
    NSString *traceback_str;
    wchar_t *wtmp_str;
    const char* app_module_str;
    const char* nslog_script;
    PyObject *app_module;
    PyObject *module;
    PyObject *module_attr;
    PyObject *method_args;
    PyObject *result;
    PyObject *exc_type;
    PyObject *exc_value;
    PyObject *exc_traceback;
    PyObject *systemExit_code;

    @autoreleasepool {
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];

        // Generate an isolated Python configuration.
        NSLog(@"Configuring isolated Python...");
        PyPreConfig_InitIsolatedConfig(&preconfig);
        PyConfig_InitIsolatedConfig(&config);

        // Configure the Python interpreter:
        // Enforce UTF-8 encoding for stderr, stdout, file-system encoding and locale.
        // See https://docs.python.org/3/library/os.html#python-utf-8-mode.
        preconfig.utf8_mode = 1;
        // Don't buffer stdio. We want output to appears in the log immediately
        config.buffered_stdio = 0;
        // Don't write bytecode; we can't modify the app bundle
        // after it has been signed.
        config.write_bytecode = 0;
        // Isolated apps need to set the full PYTHONPATH manually.
        config.module_search_paths_set = 1;
        // For debugging - enable verbose mode.
        // config.verbose = 1;

        NSLog(@"Pre-initializing Python runtime...");
        status = Py_PreInitialize(&preconfig);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to pre-initialize Python interpreter: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }

        // Set the home for the Python interpreter
        python_home = [NSString stringWithFormat:@"%@/python", resourcePath, nil];
        NSLog(@"PythonHome: %@", python_home);
        wtmp_str = Py_DecodeLocale([python_home UTF8String], NULL);
        status = PyConfig_SetString(&config, &config.home, wtmp_str);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to set PYTHONHOME: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);

        // Determine the app module name
        app_module_name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MainModule"];
        if (app_module_name == NULL) {
            NSLog(@"Unable to identify app module name.");
        }
        app_module_str = [app_module_name UTF8String];
        status = PyConfig_SetBytesString(&config, &config.run_module, app_module_str);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to set app module name: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }

        // Read the site config
        status = PyConfig_Read(&config);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to read site config: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }

        // Set the full module path. This includes the stdlib, site-packages, and app code.
        NSLog(@"PYTHONPATH:");
        // The unpacked form of the stdlib
        path = [NSString stringWithFormat:@"%@/python/lib/python{{ cookiecutter.python_version|py_tag }}", resourcePath, nil];
        NSLog(@"- %@", path);
        wtmp_str = Py_DecodeLocale([path UTF8String], NULL);
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to set unpacked form of stdlib path: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);

        // Add the app_packages path
        path = [NSString stringWithFormat:@"%@/app_packages", resourcePath, nil];
        NSLog(@"- %@", path);
        wtmp_str = Py_DecodeLocale([path UTF8String], NULL);
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to set app packages path: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);

        // Add the app path
        path = [NSString stringWithFormat:@"%@/app", resourcePath, nil];
        NSLog(@"- %@", path);
        wtmp_str = Py_DecodeLocale([path UTF8String], NULL);
        status = PyWideStringList_Append(&config.module_search_paths, wtmp_str);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to set app path: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }
        PyMem_RawFree(wtmp_str);

        NSLog(@"Configure argc/argv...");
        status = PyConfig_SetBytesArgv(&config, argc, argv);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to configure argc/argv: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }

        NSLog(@"Initializing Python runtime...");
        status = Py_InitializeFromConfig(&config);
        if (PyStatus_Exception(status)) {
            crash_dialog([NSString stringWithFormat:@"Unable to initialize Python interpreter: %s", status.err_msg, nil]);
            PyConfig_Clear(&config);
            Py_ExitStatusException(status);
        }

        @try {
            // Set the name of the python NSLog bootstrap script
            nslog_script = [
                [[NSBundle mainBundle] pathForResource:@"app_packages/nslog"
                                                ofType:@"py"] cStringUsingEncoding:NSUTF8StringEncoding];
            if (nslog_script == NULL) {
                NSLog(@"No Python NSLog handler found. stdout/stderr will not be captured.");
                NSLog(@"To capture stdout/stderr, add 'std-nslog' to your app dependencies.");
            } else {
                NSLog(@"Installing Python NSLog handler...");
                FILE* fd = fopen(nslog_script, "r");
                if (fd == NULL) {
                    crash_dialog(@"Unable to open nslog.py");
                    exit(-1);
                }

                ret = PyRun_SimpleFileEx(fd, nslog_script, 1);
                fclose(fd);
                if (ret != 0) {
                    crash_dialog(@"Unable to install Python NSLog handler");
                    exit(ret);
                }
            }

            // Start the app module.
            //
            // From here to Py_ObjectCall(runmodule...) is effectively
            // a copy of Py_RunMain() (and, more specifically, the
            // pymain_run_module() method); we need to re-implement it
            // because we need to be able to inspect the error state of
            // the interpreter, not just the return code of the module.
            NSLog(@"Running app module: %@", app_module_name);
            module = PyImport_ImportModule("runpy");
            if (module == NULL) {
                crash_dialog(@"Could not import runpy module");
                exit(-2);
            }

            module_attr = PyObject_GetAttrString(module, "_run_module_as_main");
            if (module_attr == NULL) {
                crash_dialog(@"Could not access runpy._run_module_as_main");
                exit(-3);
            }

            app_module = PyUnicode_FromString(app_module_str);
            if (app_module == NULL) {
                crash_dialog(@"Could not convert module name to unicode");
                exit(-3);
            }

            method_args = Py_BuildValue("(Oi)", app_module, 0);
            if (method_args == NULL) {
                crash_dialog(@"Could not create arguments for runpy._run_module_as_main");
                exit(-4);
            }

            // Print a separator to differentiate Python startup logs from app logs
            NSLog(@"---------------------------------------------------------------------------");

            // Invoke the app module
            result = PyObject_Call(module_attr, method_args, NULL);

            if (result == NULL) {
                // Retrieve the current error state of the interpreter.
                PyErr_Fetch(&exc_type, &exc_value, &exc_traceback);
                PyErr_NormalizeException(&exc_type, &exc_value, &exc_traceback);

                if (exc_traceback == NULL) {
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
            crash_dialog([NSString stringWithFormat:@"Python runtime error: %@", [exception reason]]);
            ret = -7;
        }
        @finally {
            Py_Finalize();
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
    // NSString *full_message = [NSString stringWithFormat:@"An unexpected error occurred.\n%@", details];
    // // Create a stack trace dialog
    // [UIAlertController alertControllerWithTitle:@"Application has crashed"
    //                                     message:full_message
    //                              preferredStyle:UIAlertControllerStyleAlert];
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
