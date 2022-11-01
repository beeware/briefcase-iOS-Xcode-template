//
//  {{ cookiecutter.class_name }}Tests.m
//  {{ cookiecutter.class_name }}Tests
//
//  Created by Russell Keith-Magee on 20/10/2022.
//  Copyright © 2022 Russell Keith-Magee. All rights reserved.
//

#import <XCTest/XCTest.h>
#include <Python.h>

@interface {{ cookiecutter.class_name }}Tests : XCTestCase {
    int ret;
    PyStatus status;
    PyConfig config;
    NSString *python_home;
    NSString *path;
    NSString *traceback_str;
    wchar_t *wapp_module_name;
    wchar_t *wtmp_str;
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
    PyObject *sys;
    PyObject *sys_argv;
}

@end

@implementation {{ cookiecutter.class_name }}Tests

- (void)setUp {
    NSString *appPath = [NSString stringWithFormat:@"%@/app", [[NSBundle mainBundle] resourcePath], nil];
    chdir([appPath UTF8String]);
}

- (void)tearDown {
}

- (void)testPython {
    // Start the app module.
    //
    sys = PyImport_ImportModule("sys");
    if (module == NULL) {
        XCTFail(@"Could not import sys module");
    }
    sys_argv = PyObject_GetAttrString(sys, "argv");
    if (module_attr == NULL) {
        XCTFail(@"Could not access sys.argv");
    }

    // From here to Py_ObjectCall(runmodule...) is effectively
    // a copy of Py_RunMain() (and, more specifically, the
    // pymain_run_module() method); we need to re-implement it
    // because we need to be able to inspect the error state of
    // the interpreter, not just the return code of the module.
    NSLog(@"Running test module");
    module = PyImport_ImportModule("runpy");
    if (module == NULL) {
        XCTFail(@"Could not import runpy module");
    }

    module_attr = PyObject_GetAttrString(module, "_run_module_as_main");
    if (module_attr == NULL) {
        XCTFail(@"Could not access runpy._run_module_as_main");
    }

    wchar_t *wtest_module_name = Py_DecodeLocale("pytest", NULL);
    app_module = PyUnicode_FromWideChar(wtest_module_name, wcslen(wtest_module_name));
    if (app_module == NULL) {
        XCTFail(@"Could not convert module name to unicode");
    }

    method_args = Py_BuildValue("(Oi)", app_module, 0);
    if (method_args == NULL) {
        XCTFail(@"Could not create arguments for runpy._run_module_as_main");
    }

    result = PyObject_Call(module_attr, method_args, NULL);

    if (result == NULL) {
        // Retrieve the current error state of the interpreter.
        PyErr_Fetch(&exc_type, &exc_value, &exc_traceback);
        PyErr_NormalizeException(&exc_type, &exc_value, &exc_traceback);

        if (exc_traceback == NULL) {
            XCTFail(@"Could not retrieve traceback");
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
        XCTAssertEqual(ret, 0, "Python test suite failed");
    } else {
        XCTFail(@"Test suite could not be executed");
    }
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
