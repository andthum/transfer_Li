#####################
Transfer Lithium Ions
#####################

|pre-commit| |pre-commit.ci_status| |Test_Status| |CodeQL_Status|
|License_MIT| |Made_with_Bash| |Made_with_Python| |Code_style_black|

This is just a small helper package that contains scripts to

* Find lithium ions directly attached to the negative electrode in a
  molecular dynamics (MD) simulation.
* Find suitable insertion places at the positive electrode at which
  lithium ions can be inserted.
* Transfer/Relocate the lithium ions from the negative to the positive
  electrode.
* (Re-)Start the MD simulation.


Context / Overall Goal
----------------------

Investigate how the electrolyte structure relaxes when taking away a
lithium ion at the negative electrode.  To do so, remove a lithium ion
from the first layer at the negative electrode and insert it at the
positive electrode.

Note that the lithium ion cannot simply be removed but must be
re-inserted to keep an overall charge-neutral system.  Otherwise, the
Ewald summation will probably lead to artifacts
(J. S. Hub, B. L. de Groot, H. Grubmüller, G. Groenhof,
`Quantifying Artifacts in Ewald Simulations of Inhomogeneous Systems
with a Net Charge <https://doi.org/10.1021/ct400626b>`_
Journal of Chemical Theory and Computation, 2014, 10, 1, 381-390).


.. |pre-commit| image:: https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white
    :alt: pre-commit
    :target: https://github.com/pre-commit/pre-commit
.. |pre-commit.ci_status| image:: https://results.pre-commit.ci/badge/github/andthum/transfer_Li/main.svg
    :alt: pre-commit.ci status
    :target: https://results.pre-commit.ci/latest/github/andthum/transfer_Li/main
.. |Test_Status| image:: https://github.com/andthum/transfer_Li/actions/workflows/tests.yml/badge.svg
    :alt: Test Status
    :target: https://github.com/andthum/transfer_Li/actions/workflows/tests.yml
.. |CodeQL_Status| image:: https://github.com/andthum/transfer_Li/actions/workflows/codeql-analysis.yml/badge.svg
    :alt: CodeQL Status
    :target: https://github.com/andthum/transfer_Li/actions/workflows/codeql-analysis.yml
.. |License_MIT| image:: https://img.shields.io/badge/License-MIT-blue.svg
    :alt: MIT License
    :target: https://mit-license.org/
.. |Made_with_Bash| image:: https://img.shields.io/badge/Made%20with-Bash-1f425f.svg
    :alt: Made with Bash
    :target: https://www.gnu.org/software/bash/
.. |Made_with_Python| image:: https://img.shields.io/badge/Made%20with-Python-1f425f.svg
    :alt: Made with Python
    :target: https://www.python.org/
.. |Code_style_black| image:: https://img.shields.io/badge/code%20style-black-000000.svg
    :alt: Code style black
    :target: https://github.com/psf/black
