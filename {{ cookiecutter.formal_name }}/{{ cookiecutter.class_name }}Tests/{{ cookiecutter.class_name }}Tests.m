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
    NSString *pluginsPath;
    NSString *tests_path;
    NSString *test_packages_path;
    PyGILState_STATE gstate;
}

@end

@implementation {{ cookiecutter.class_name }}Tests

- (void)setUp {
    int ret = 0;
    PyObject *module;
    PyObject *module_attr;

    // Test code is contained in a plugin path
    pluginsPath = [[NSBundle mainBundle] builtInPlugInsPath];

    tests_path = [NSString stringWithFormat:@"%@/{{ cookiecutter.class_name }}Tests.xctest/tests", pluginsPath, nil];
    NSLog(@"Tests path: %@", tests_path);

    test_packages_path = [NSString stringWithFormat:@"%@/{{ cookiecutter.class_name }}Tests.xctest/test_packages", pluginsPath, nil];
    NSLog(@"Test packages path: %@", test_packages_path);

    // Set the working directory to be the tests path
    chdir([tests_path UTF8String]);

    // Acquire the GIL state.
    gstate = PyGILState_Ensure();

    // Obtain sys.path so we can add the test code paths
    module = PyImport_ImportModule("sys");
    if (module == NULL) {
        XCTFail(@"Could not access sys");
        return;
    }
    module_attr = PyObject_GetAttrString(module, "path");
    if (module_attr == NULL) {
        XCTFail(@"Could not access sys.path");
        return;
    }

    // Add test packages to sys.path
    ret = PyList_Insert(module_attr, 0, PyUnicode_FromString([test_packages_path UTF8String]));
    if (ret != 0)
    {
        XCTFail(@"Could not add test packages to system path");
        return;
    }

    ret = PyList_Insert(module_attr, 0, PyUnicode_FromString([tests_path UTF8String]));
    if (ret != 0)
    {
        XCTFail(@"Could not add test code to system path");
        return;
    }
}

- (void)tearDown {
    PyGILState_Release(gstate);
}

- (void)testPython {
    int ret = 0;
    PyObject *module;
    PyObject *module_attr;
    PyObject *method_args;
    PyObject *result;
    PyObject *test_module;
    PyObject *exc_type;
    PyObject *exc_value;
    PyObject *exc_traceback;
    PyObject *systemExit_code;

    // From here to Py_ObjectCall(runmodule...) is effectively
    // a copy of Py_RunMain() (and, more specifically, the
    // pymain_run_module() method); we need to re-implement it
    // because we need to be able to inspect the error state of
    // the interpreter, not just the return code of the module.
    NSLog(@"Running test module");
    module = PyImport_ImportModule("runpy");
    if (module == NULL) {
        XCTFail(@"Could not import runpy module");
        return;
    }

    module_attr = PyObject_GetAttrString(module, "_run_module_as_main");
    if (module_attr == NULL) {
        XCTFail(@"Could not access runpy._run_module_as_main");
        return;
    }

    test_module = PyUnicode_FromString("run_tests");
    if (test_module == NULL) {
        XCTFail(@"Could not convert test runner name to unicode");
        return;
    }

    method_args = Py_BuildValue("(Oi)", test_module, 0);
    if (method_args == NULL) {
        XCTFail(@"Could not create arguments for runpy._run_module_as_main");
        return;
    }

    result = PyObject_Call(module_attr, method_args, NULL);

    // A well-behaved test suite will raise SystemExit() with 0 in the case
    // of a success, non-zero in the case of failure. If we don't get that,
    // then the test suite wasn't successful.
    if (result == NULL) {
        // Retrieve the current error state of the interpreter.
        PyErr_Fetch(&exc_type, &exc_value, &exc_traceback);
        PyErr_NormalizeException(&exc_type, &exc_value, &exc_traceback);

        if (exc_traceback == NULL) {
            XCTFail("Could not retrieve traceback from Python test suite.");
        } else if (PyErr_GivenExceptionMatches(exc_value, PyExc_SystemExit)) {
            // If it's a SystemExit, get the exit code, and use that
            // to determine whether the test suite passed or failed.
            systemExit_code = PyObject_GetAttrString(exc_value, "code");
            if (systemExit_code == NULL) {
                XCTFail("Could not determine exit code from Python test suite.");
            } else {
                XCTAssertEqual(ret, PyLong_AsLong(systemExit_code), "Python test suite failed!");
            }
        } else {
            // Restore the error state of the interpreter.
            PyErr_Restore(exc_type, exc_value, exc_traceback);

            // Print exception to stderr.
            PyErr_Print();
            XCTFail("Python test suite did not run successfully.");
        }
    } else {
        XCTFail("Python test suite did not exit with success/fail.");
    }
}

@end
