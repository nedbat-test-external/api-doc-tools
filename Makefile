.PHONY: build_docs build_dummy_translations clean compile_translations \
        coverage detect_changed_source_translations diff_cover docs \
        dummy_translations extract_translations help isort isort_check \
        pip-tools pull_translations push_translations pylint quality \
        requirements selfcheck style test test-all upgrade upgrade \
        upgrade-pip-tools validate validate_translations

.DEFAULT_GOAL := help

# For opening files in a browser. Use like: $(BROWSER)relative/path/to/file.html
BROWSER := python -m webbrowser file://$(CURDIR)/

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@awk -F ':.*?## ' '/^[a-zA-Z]/ && NF==2 {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

coverage: clean ## generate and view HTML coverage report
	pytest --cov-report html
	$(BROWSER)htmlcov/index.html

build_docs:
	doc8 --ignore-path docs/_build README.rst docs
	rm -f docs/edx_api_doc_tools.rst
	rm -f docs/modules.rst
	make -C docs clean
	make -C docs html
	python setup.py check --restructuredtext --strict

docs: build_docs ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER)docs/_build/html/index.html

pip-tools:
	pip install -qr requirements/pip-tools.txt

upgrade-pip-tools: pip-tools
	pip-compile --upgrade requirements/pip-tools.in

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: upgrade-pip-tools ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	# Make sure to compile files after any other files they include!
	make pip-tools  # Reinstall pip-tools in case it was upgraded.
	pip-compile --upgrade requirements/base.in
	pip-compile --upgrade requirements/test.in
	pip-compile --upgrade requirements/doc.in
	pip-compile --upgrade requirements/quality.in
	pip-compile --upgrade requirements/travis.in
	pip-compile --upgrade requirements/dev.in
	# Let tox control the Django version for tests
	sed '/^[dD]jango==/d' requirements/test.txt > requirements/test.tmp
	mv requirements/test.tmp requirements/test.txt

CHECKABLE_PYTHON=tests test_utils example edx_api_doc_tools manage.py setup.py test_settings.py

style:
	pycodestyle $(CHECKABLE_PYTHON)
	pydocstyle $(CHECKABLE_PYTHON)

isort:  # sort all imports.
	isort --recursive $(CHECKABLE_PYTHON)

isort_check:
	isort --check-only --diff --recursive $(CHECKABLE_PYTHON)

pylint:
	echo '"""This file exists only to satisify pylint; it is not committed."""' > tests/__init__.py
	pylint $(CHECKABLE_PYTHON)
	pylint --py3k $(CHECKABLE_PYTHON)
	rm tests/__init__.py

quality: style isort_check pylint ## check code style, import ordering, linting, and this makefile
	make selfcheck

requirements: pip-tools ## install development environment requirements
	pip-sync requirements/dev.txt requirements/private.*

test: clean ## run tests in the current virtualenv
	pytest

diff_cover: test ## find diff lines that need test coverage
	diff-cover coverage.xml

test-all: quality ## run tests on every supported Python/Django combination
	tox

validate: quality test ## run tests and quality checks

selfcheck: ## check that the Makefile is well-formed
	@echo "The Makefile is well-formed."

## Localization targets

extract_translations: ## extract strings to be translated, outputting .mo files
	rm -rf docs/_build
	cd edx_api_doc_tools && ../manage.py makemessages -l en -v1 -d django
	cd edx_api_doc_tools && ../manage.py makemessages -l en -v1 -d djangojs

compile_translations: ## compile translation files, outputting .po files for each supported language
	cd edx_api_doc_tools && ../manage.py compilemessages

detect_changed_source_translations:
	cd edx_api_doc_tools && i18n_tool changed

pull_translations: ## pull translations from Transifex
	tx pull -af --mode reviewed

push_translations: ## push source translation files (.po) from Transifex
	tx push -s

dummy_translations: ## generate dummy translation (.po) files
	cd edx_api_doc_tools && i18n_tool dummy

build_dummy_translations: extract_translations dummy_translations compile_translations ## generate and compile dummy translation files

validate_translations: build_dummy_translations detect_changed_source_translations ## validate translations
