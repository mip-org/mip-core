from setuptools import setup, find_packages

setup(
    name="mip_build_helpers",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "requests",
    ],
    python_requires=">=3.6",
    author="mip contributors",
    description="Helper functions for building MATLAB package (.mhl) files",
    long_description="Helper functions for building MATLAB package (.mhl) files.",
    long_description_content_type="text/plain",
)
