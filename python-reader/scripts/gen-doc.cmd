:: Generates HTML docs
pyreverse -o png -p Pyreverse src\python_template src\config -d docs\source\_static
autopep8 --verbose --aggressive -r --in-place src/
pip-licenses -f md > docs\source\licenses.md
sphinx-apidoc -o docs\source src\ & sphinx-build -b html docs\source docs\build
start docs\build\index.html