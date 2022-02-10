# Low Voltage Feeder Taxonomy (LVFT) Representative Network Reader

Example code for reading the Low Voltage Feeder Taxonomy representative network DSS files using Ditto, converting to
NetworkX graphs and rendering to HTML/PNG

## Quickstart

To get started quickly, install a few things. See Setup section below for instructions.

Required:

- Git
- [Python 3.9](https://www.python.org/downloads/)
- [Poetry 1.1](https://github.com/python-poetry/poetry)

Then grab the code, build and run it from a command prompt (bash, cmd, powershell, whatever) like this. Tested in
windows, should be similar in other OSes:

```shell
git clone <repo-url.git>  

# Now tell poetry which python install to use. On windows with normal python, it'll be like: C:\Users\wes148\Python\Python39\python.exe
poetry env use path/to/python3.9.exe 
poetry install # install all dependencies (direct and transitive) listed in project.toml
poetry shell # activate virtual environment
python --version # make sure this is v3.9 (or whatever your set above with `poetry env use ...`).
python src\python_template\example.py #run code
pytest # run unit tests - generates network renders
dir output # view test outputs
```