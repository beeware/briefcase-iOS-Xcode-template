Briefcase iOS Xcode Template
============================

A `Cookiecutter <https://github.com/cookiecutter/cookiecutter/>`__ template for
building Python apps that will run under iOS.

Using this template
-------------------

The easiest way to use this project is to not use it at all - at least, not
directly. `Briefcase <https://github.com/beeware/briefcase/>`__ is a tool that
uses this template, rolling it out using data extracted from a
``pyproject.toml`` configuration file.

However, if you *do* want use this template directly...

1. Install `cookiecutter`_. This is a tool used to bootstrap complex project
   templates::

    $ pip install cookiecutter

2. Run ``cookiecutter`` on the template::

    $ cookiecutter https://github.com/beeware/briefcase-iOS-Xcode-template

   This will ask you for a number of details of your application, including the
   `name` of your application (which should be a valid PyPI identifier), and
   the `Formal Name` of your application (the full name you use to describe
   your app). The remainder of these instructions will assume a `name` of
   ``my-project``, and a formal name of ``My Project``.

3. `Obtain a Python Apple support package for iOS`_, and extract it into
   the ``My Project`` directory generated by the template. This will give you a
   ``My Project/Support`` directory containing a self contained Python install.

4. Add your code to the template, into the ``My Project/my-project/app``.
   directory. At the very minimum, you need to have an
   ``app/<app name>/__main__.py`` file that defines a ``PythonAppDelegate``
   class.

   If your code has any dependencies, they should be installed into the
   ``My Project/my-project/app_packages`` directory.

If you've done this correctly, a project with a formal name of ``My Project``,
with an app name of ``my-project`` should have a directory structure that
looks something like::

    My Project/
        my-project/
            app/
                my_project/
                    __init__.py
                    app.py (declares PythonAppDelegate)
            app_packages/
                ...
            ...
        My Project.xcodeproj/
            ...
        Support/
            ...
        briefcase.toml

You're now ready to open the XCode project file, build and run your project!

Next steps
----------

Of course, running Python code isn't very interesting by itself - you'll be
able to output to the console, and see that output in XCode, but if you tap the
app icon on your phone, you won't see anything - because there isn't a visible
console on an iPhone.

To do something interesting, you'll need to work with the native iOS system
libraries to draw widgets and respond to screen taps. The `Rubicon`_ Objective
C bridging library can be used to interface with the iOS system libraries.
Alternatively, you could use a cross-platform widget toolkit that supports iOS
(such as `Toga`_) to provide a GUI for your application.

Regardless of whether you use Toga, or you write an application natively, the
template project will try to instantiate a ``UIApplicationMain`` instance,
using a class named ``PythonAppDelegate`` as the App delegate. If a class of
that name can't be instantiated, the error raised will be logged, and the
Python interpreter will be shut down.

If you have any external library dependencies (like Toga, or anything other
third-party library), you should install the library code into the
``app_packages`` directory. This directory is the same as a  ``site_packages``
directory on a desktop Python install.

.. _cookiecutter: https://github.com/cookiecutter/cookiecutter
.. _Obtain a Python Apple support package for iOS: https://github.com/beeware/Python-Apple-support
.. _Rubicon: https://github.com/beeware/rubicon-objc
.. _Toga: https://beeware.org/project/projects/libraries/toga
