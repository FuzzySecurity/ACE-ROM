PYTHON ?= python3

.PHONY: all clean validate
all:
	$(PYTHON) tools/build.py

validate: all
	$(PYTHON) tools/validate.py

clean:
	$(PYTHON) -c 'import shutil; shutil.rmtree("build", ignore_errors=True)'
