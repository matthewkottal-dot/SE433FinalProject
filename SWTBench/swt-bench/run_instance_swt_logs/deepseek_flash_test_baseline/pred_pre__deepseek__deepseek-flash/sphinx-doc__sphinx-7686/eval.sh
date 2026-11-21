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
diff --git a/tests/roots/test-ext-autosummary-imported-members-disabled/_templates/autosummary/module_members.rst b/tests/roots/test-ext-autosummary-imported-members-disabled/_templates/autosummary/module_members.rst
new file mode 100644
index 000000000..910201801
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-imported-members-disabled/_templates/autosummary/module_members.rst
@@ -0,0 +1,5 @@
+{{ fullname | escape | underline }}
+
+{% for item in members %}
+{{ item }}
+{%- endfor %}
diff --git a/tests/roots/test-ext-autosummary-imported-members-disabled/conf.py b/tests/roots/test-ext-autosummary-imported-members-disabled/conf.py
new file mode 100644
index 000000000..18fb5f8d4
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-imported-members-disabled/conf.py
@@ -0,0 +1,8 @@
+import os
+import sys
+sys.path.insert(0, os.path.abspath('.'))
+
+extensions = ['sphinx.ext.autosummary']
+autosummary_generate = True
+autosummary_imported_members = False
+templates_path = ['_templates']
diff --git a/tests/roots/test-ext-autosummary-imported-members-disabled/index.rst b/tests/roots/test-ext-autosummary-imported-members-disabled/index.rst
new file mode 100644
index 000000000..f577e07ab
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-imported-members-disabled/index.rst
@@ -0,0 +1,5 @@
+.. autosummary::
+   :toctree: generated
+   :template: module_members
+
+   target
diff --git a/tests/roots/test-ext-autosummary-imported-members-disabled/target.py b/tests/roots/test-ext-autosummary-imported-members-disabled/target.py
new file mode 100644
index 000000000..9dc4303ae
--- /dev/null
+++ b/tests/roots/test-ext-autosummary-imported-members-disabled/target.py
@@ -0,0 +1,6 @@
+import os
+
+
+def local_function():
+    """A function defined by this module."""
+    pass
diff --git a/tests/test_ext_autosummary.py b/tests/test_ext_autosummary.py
index 166029ccb..fe3436422 100755
--- a/tests/test_ext_autosummary.py
+++ b/tests/test_ext_autosummary.py
@@ -346,6 +346,18 @@ def test_autosummary_mock_imports(app, status, warning):
         sys.modules.pop('foo', None)  # unload foo module
 
 
+@pytest.mark.sphinx('dummy', testroot='ext-autosummary-imported-members-disabled')
+def test_autosummary_imported_members_disabled(app, status, warning):
+    try:
+        app.build()
+
+        content = (app.srcdir / 'generated' / 'target.rst').read_text()
+        assert 'local_function' in content.splitlines()
+        assert 'os' not in content.splitlines()
+    finally:
+        sys.modules.pop('target', None)
+
+
 @pytest.mark.sphinx('dummy', testroot='ext-autosummary-imported_members')
 def test_autosummary_imported_members(app, status, warning):
     try:

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autosummary/generate\.py)' -m tox -epy39 -v -- tests/roots/test-ext-autosummary-imported-members-disabled/_templates/autosummary/module_members.rst tests/roots/test-ext-autosummary-imported-members-disabled/conf.py tests/roots/test-ext-autosummary-imported-members-disabled/index.rst tests/roots/test-ext-autosummary-imported-members-disabled/target.py tests/test_ext_autosummary.py
cat coverage.cover
git checkout 752d3285d250bbaf673cff25e83f03f247502021
git apply /root/pre_state.patch
