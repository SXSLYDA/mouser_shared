import os

import setuptools

# Read the version WITHOUT importing the mouser_lookup package: its
# __init__ imports client.py, which needs `requests` - and that isn't
# installed yet in pip's isolated build environment, so an import here
# would fail the install. bump-version.ps1 updates version.py.
_version = {}
with open(os.path.join(os.path.dirname(__file__), "mouser_lookup", "version.py")) as f:
    exec(f.read(), _version)

setuptools.setup(
    name="mouser-lookup",
    version=_version["MOUSER_LOOKUP_VERSION"],
    description="Framework-agnostic Mouser Electronics search client + prefill mapping for OMG Harness and the InvenTree import plugin.",
    packages=setuptools.find_packages(),
    install_requires=["requests"],
    python_requires=">=3.9",
)