#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
    Setup file for devs.

    This file was generated with PyScaffold 1.2, a tool that easily
    puts up a scaffold for your new Python project. Learn more under:
    http://pyscaffold.readthedocs.org/
"""

import inspect
import os
import sys
from distutils.cmd import Command

import setuptools
from setuptools import setup
from setuptools.command.test import test as TestCommand

from distutils.extension import Extension
from Cython.Build import cythonize

import versioneer

__location__ = os.path.join(os.getcwd(), os.path.dirname(
    inspect.getfile(inspect.currentframe())))

# Change these settings according to your needs
MAIN_PACKAGE = "devs"
DESCRIPTION = (
    "A Python wrapper of adevs, a C++ library implementing the Discrete Event "
    "System Specification (DEVS)"
)
LICENSE = "apache"
URL = "http://github.com/andsor/pydevs"
AUTHOR = "Andreas Sorge"
EMAIL = "as@asorge.de"

# Add here all kinds of additional classifiers as defined under
# https://pypi.python.org/pypi?%3Aaction=list_classifiers
CLASSIFIERS = [
    'Development Status :: 3 - Alpha',
    'License :: OSI Approved :: Apache Software License',
    'Programming Language :: Python',
    'Programming Language :: Python :: 2.7',
    'Programming Language :: Python :: 3.4',
]

# Add here console scripts like ['hello_world = devs.module:function']
CONSOLE_SCRIPTS = []

# Versioneer configuration
versioneer.VCS = 'git'
versioneer.versionfile_source = os.path.join(MAIN_PACKAGE, '_version.py')
versioneer.versionfile_build = os.path.join(MAIN_PACKAGE, '_version.py')
versioneer.tag_prefix = 'v'  # tags are like 1.2.0
versioneer.parentdir_prefix = MAIN_PACKAGE + '-'


class Tox(TestCommand):

    user_options = [
        ('tox-args=', 'a', "Arguments to pass to tox"),
    ]

    def initialize_options(self):
        TestCommand.initialize_options(self)
        self.tox_args = None

    def finalize_options(self):
        TestCommand.finalize_options(self)
        self.test_args = []
        self.test_suite = True

    def run_tests(self):
        # import here, cause outside the eggs aren't loaded
        import tox
        import shlex
        errno = tox.cmdline(
            args=shlex.split(self.tox_args) if self.tox_args else None
        )
        sys.exit(errno)


class ToxAutoDocs(Tox):

    def finalize_options(self):
        Tox.finalize_options(self)
        if self.tox_args is None:
            self.tox_args = ''
        self.tox_args += ' -e autodocs '


def sphinx_builder():
    try:
        from sphinx.setup_command import BuildDoc
    except ImportError:
        class NoSphinx(Command):
            user_options = []

            def initialize_options(self):
                raise RuntimeError("Sphinx documentation is not installed, "
                                   "run: pip install sphinx")

        return NoSphinx

    class BuildSphinxDocs(BuildDoc):

        def run(self):
            if self.builder == "doctest":
                import sphinx.ext.doctest as doctest
                # Capture the DocTestBuilder class in order to return the total
                # number of failures when exiting
                ref = capture_objs(doctest.DocTestBuilder)
                BuildDoc.run(self)
                errno = ref[-1].total_failures
                sys.exit(errno)
            else:
                BuildDoc.run(self)

    return BuildSphinxDocs


class ObjKeeper(type):
    instances = {}

    def __init__(cls, name, bases, dct):
        cls.instances[cls] = []

    def __call__(cls, *args, **kwargs):
        cls.instances[cls].append(super(ObjKeeper, cls).__call__(*args,
                                                                 **kwargs))
        return cls.instances[cls][-1]


def capture_objs(cls):
    from six import add_metaclass
    module = inspect.getmodule(cls)
    name = cls.__name__
    keeper_class = add_metaclass(ObjKeeper)(cls)
    setattr(module, name, keeper_class)
    cls = getattr(module, name)
    return keeper_class.instances[cls]


def get_install_requirements(path):
    content = open(os.path.join(__location__, path)).read()
    return [req for req in content.split("\\n") if req != '']


def read(fname):
    return open(os.path.join(__location__, fname)).read()


def setup_package():
    # Assemble additional setup commands
    cmdclass = versioneer.get_cmdclass()
    cmdclass['docs'] = sphinx_builder()
    cmdclass['doctest'] = sphinx_builder()
    cmdclass['test'] = Tox
    cmdclass['autodocs'] = ToxAutoDocs

    # Some helper variables
    version = versioneer.get_version()
    docs_path = os.path.join(__location__, "docs")
    docs_build_path = os.path.join(docs_path, "_build")
    install_reqs = get_install_requirements("requirements.txt")
    extra_doc_reqs = get_install_requirements("requirements-doc.txt")

    command_options = {
        'docs': {'project': ('setup.py', MAIN_PACKAGE),
                 'version': ('setup.py', version.split('-', 1)[0]),
                 'release': ('setup.py', version),
                 'build_dir': ('setup.py', docs_build_path),
                 'config_dir': ('setup.py', docs_path),
                 'source_dir': ('setup.py', docs_path)},
        'doctest': {'project': ('setup.py', MAIN_PACKAGE),
                    'version': ('setup.py', version.split('-', 1)[0]),
                    'release': ('setup.py', version),
                    'build_dir': ('setup.py', docs_build_path),
                    'config_dir': ('setup.py', docs_path),
                    'source_dir': ('setup.py', docs_path),
                    'builder': ('setup.py', 'doctest')},
        'test': {'test_suite': ('setup.py', 'tests')},
    }

    # extensions
    devs_extension = Extension("devs.devs",
                               sources=['devs/devs.pyx'],
                               language='c++',
                               include_dirs=['vendor/adevs/include', ],
                               extra_compile_args=['--std=c++11', ])

    setup(name=MAIN_PACKAGE,
          version=version,
          url=URL,
          description=DESCRIPTION,
          author=AUTHOR,
          author_email=EMAIL,
          license=LICENSE,
          long_description=read('README.rst'),
          classifiers=CLASSIFIERS,
          test_suite='tests',
          packages=setuptools.find_packages(exclude=['tests', 'tests.*']),
          install_requires=install_reqs,
          setup_requires=['six', 'setuptools_git>=1.1'],
          cmdclass=cmdclass,
          tests_require=['tox'],
          command_options=command_options,
          entry_points={'console_scripts': CONSOLE_SCRIPTS},
          extras_require={
              'docs': extra_doc_reqs,
          },
          include_package_data=True,  # include everything in source control
          # but exclude these files
          exclude_package_data={'': ['.gitignore']},
          ext_modules=cythonize(devs_extension),
          )

if __name__ == "__main__":
    setup_package()
