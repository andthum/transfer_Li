# Setup instructions.  For more details about how to create a python
# package take a look at
# https://packaging.python.org/overview/
# and specifically at
# https://packaging.python.org/guides/distributing-packages-using-setuptools/
# and
# https://packaging.python.org/tutorials/packaging-projects/

# Setup instructions are contained in `pyproject.toml`.  This file is
# basically empty and is only required for editable installs with pip
# versions <21.1.  See
# https://setuptools.pypa.io/en/latest/userguide/quickstart.html#development-mode


"""Setuptools-based setup script for this project."""


__author__ = "Andreas Thum"


# Third-party libraries
import setuptools


if __name__ == "__main__":
    setuptools.setup()
