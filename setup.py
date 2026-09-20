import setuptools

setuptools.setup(
    name="mouser-lookup",
    version="0.1.0",
    description="Framework-agnostic Mouser Electronics search client + prefill mapping for OMG Harness and the InvenTree import plugin.",
    packages=setuptools.find_packages(),
    install_requires=["requests"],
    python_requires=">=3.9",
)
