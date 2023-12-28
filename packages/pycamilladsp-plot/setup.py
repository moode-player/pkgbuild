import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

setuptools.setup(
    name="camilladsp_plot",
    version="2.0.0",
    author="Henrik Enquist",
    author_email="henrik.enquist@gmail.com",
    description="A library for validating, evaluating and plotting configs and filters for CamillaDSP",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/HEnquist/pycamilladsp-plot",
    packages=setuptools.find_packages(),
    python_requires=">=3",
    package_data={'camilladsp_plot': ['schemas/*.json']},
    install_requires=["PyYAML", "jsonschema"],
    entry_points={
        'console_scripts': ['plotcamillaconf=camilladsp_plot.plotcamillaconf:main'],
    }
)
