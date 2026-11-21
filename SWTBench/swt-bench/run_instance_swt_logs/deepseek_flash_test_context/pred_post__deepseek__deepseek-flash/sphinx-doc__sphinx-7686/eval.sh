#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 752d3285d250bbaf673cff25e83f03f247502021 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 752d3285d250bbaf673cff25e83f03f247502021
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/ext/autosummary/generate.py b/sphinx/ext/autosummary/generate.py
--- a/sphinx/ext/autosummary/generate.py
+++ b/sphinx/ext/autosummary/generate.py
@@ -18,6 +18,7 @@
 """
 
 import argparse
+import inspect
 import locale
 import os
 import pkgutil
@@ -176,6 +177,56 @@ def render(self, template_name: str, context: Dict) -> str:
 # -- Generating output ---------------------------------------------------------
 
 
+class ModuleScanner:
+    def __init__(self, app: Any, obj: Any) -> None:
+        self.app = app
+        self.object = obj
+
+    def get_object_type(self, name: str, value: Any) -> str:
+        return get_documenter(self.app, value, self.object).objtype
+
+    def is_skipped(self, name: str, value: Any, objtype: str) -> bool:
+        try:
+            return self.app.emit_firstresult('autodoc-skip-member', objtype,
+                                             name, value, False, {})
+        except Exception as exc:
+            logger.warning(__('autosummary: failed to determine %r to be documented, '
+                              'the following exception was raised:\n%s'),
+                           name, exc, type='autosummary')
+            return False
+
+    def scan(self, imported_members: bool) -> List[str]:
+        members = []
+        for name in dir(self.object):
+            try:
+                value = safe_getattr(self.object, name)
+            except AttributeError:
+                value = None
+
+            objtype = self.get_object_type(name, value)
+            if self.is_skipped(name, value, objtype):
+                continue
+
+            try:
+                if inspect.ismodule(value):
+                    imported = True
+                elif safe_getattr(value, '__module__') != self.object.__name__:
+                    imported = True
+                else:
+                    imported = False
+            except AttributeError:
+                imported = False
+
+            if imported_members:
+                # list all members up
+                members.append(name)
+            elif imported is False:
+                # list not-imported members up
+                members.append(name)
+
+        return members
+
+
 def generate_autosummary_content(name: str, obj: Any, parent: Any,
                                  template: AutosummaryRenderer, template_name: str,
                                  imported_members: bool, app: Any,
@@ -246,7 +297,8 @@ def get_modules(obj: Any) -> Tuple[List[str], List[str]]:
     ns.update(context)
 
     if doc.objtype == 'module':
-        ns['members'] = dir(obj)
+        scanner = ModuleScanner(app, obj)
+        ns['members'] = scanner.scan(imported_members)
         ns['functions'], ns['all_functions'] = \
             get_members(obj, {'function'}, imported=imported_members)
         ns['classes'], ns['all_classes'] = \

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/roots/test-ext-autosummary-members/_templates/autosummary/module.rst b/tests/roots/test-ext-autosummary-members/_templates/autosummary/module.rst
new file mode 100644
index 000000000..e9329e124
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-members/_templates/autosummary/module.rst
@@ -0,0 +1,8 @@
+{{ fullname | escape | underline }}
+
+.. automodule:: {{ fullname }}
+
+   .. autosummary::
+   {% for item in members %}
+      {{ item }}
+   {%- endfor %}
diff --git a/tests/roots/test-ext-autosummary-members/conf.py b/tests/roots/test-ext-autosummary-members/conf.py
new file mode 100644
index 000000000..720dceaae
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-members/conf.py
@@ -0,0 +1,9 @@
+import os
+import sys
+
+sys.path.insert(0, os.path.abspath('.'))
+
+extensions = ['sphinx.ext.autosummary']
+autosummary_generate = True
+autosummary_imported_members = False
+templates_path = ['_templates']
diff --git a/tests/roots/test-ext-autosummary-members/example.py b/tests/roots/test-ext-autosummary-members/example.py
new file mode 100644
index 000000000..9eeaf7645
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-members/example.py
@@ -0,0 +1,5 @@
+import os
+
+
+def local_function():
+    """A function defined in this module."""
diff --git a/tests/roots/test-ext-autosummary-members/index.rst b/tests/roots/test-ext-autosummary-members/index.rst
new file mode 100644
index 000000000..63f5e93d4
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-members/index.rst
@@ -0,0 +1,7 @@
+test-ext-autosummary-members
+============================
+
+.. autosummary::
+   :toctree: generated
+
+   example
diff --git a/tests/test_ext_autosummary.py b/tests/test_ext_autosummary.py
index 166029ccb..194b8a97a 100755
--- a/tests/test_ext_autosummary.py
+++ b/tests/test_ext_autosummary.py
@@ -399,6 +399,18 @@ def test_autosummary_template(app):
     assert 'EMPTY' in content
 
 
+@pytest.mark.sphinx(testroot='ext-autosummary-members')
+def test_autosummary_members_does_not_include_imported_members(app):
+    try:
+        app.build()
+
+        content = (app.srcdir / 'generated' / 'example.rst').read_text()
+        assert '      local_function\n' in content
+        assert '      os' not in content
+    finally:
+        sys.modules.pop('example', None)
+
+
 @pytest.mark.sphinx('dummy', testroot='ext-autosummary',
                     confoverrides={'autosummary_generate': []})
 def test_empty_autosummary_generate(app, status, warning):

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autosummary/generate\.py)' -m tox -epy39 -v -- tests/roots/test-ext-autosummary-members/_templates/autosummary/module.rst tests/roots/test-ext-autosummary-members/conf.py tests/roots/test-ext-autosummary-members/example.py tests/roots/test-ext-autosummary-members/index.rst tests/test_ext_autosummary.py
cat coverage.cover
git checkout 752d3285d250bbaf673cff25e83f03f247502021
git apply /root/pre_state.patch
