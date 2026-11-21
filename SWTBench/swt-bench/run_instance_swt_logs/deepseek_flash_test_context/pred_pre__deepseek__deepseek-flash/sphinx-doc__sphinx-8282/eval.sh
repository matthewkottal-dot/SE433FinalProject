#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2c2335bbb8af99fa132e1573bbf45dc91584d5a2 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2c2335bbb8af99fa132e1573bbf45dc91584d5a2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc.py b/tests/test_ext_autodoc.py
index c0676f23f..81d834e8b 100755
--- a/tests/test_ext_autodoc.py
+++ b/tests/test_ext_autodoc.py
@@ -2149,3 +2149,58 @@ def test_name_mangling(app):
         '      name of Foo',
         '',
     ]
+
+
+@pytest.mark.sphinx('html', testroot='ext-autodoc',
+                    confoverrides={'autodoc_typehints': 'none'})
+def test_overload_with_autodoc_typehints_none(app):
+    options = {"members": None}
+    actual = do_autodoc(app, 'module', 'target.overload', options)
+    assert list(actual) == [
+        '',
+        '.. py:module:: target.overload',
+        '',
+        '',
+        '.. py:class:: Bar(x, y)',
+        '              Bar(x, y)',
+        '   :module: target.overload',
+        '',
+        '   docstring',
+        '',
+        '',
+        '.. py:class:: Baz(x, y)',
+        '              Baz(x, y)',
+        '   :module: target.overload',
+        '',
+        '   docstring',
+        '',
+        '',
+        '.. py:class:: Foo(x, y)',
+        '              Foo(x, y)',
+        '   :module: target.overload',
+        '',
+        '   docstring',
+        '',
+        '',
+        '.. py:class:: Math()',
+        '   :module: target.overload',
+        '',
+        '   docstring',
+        '',
+        '',
+        '   .. py:method:: Math.sum(x, y)',
+        '                  Math.sum(x, y)',
+        '                  Math.sum(x, y)',
+        '      :module: target.overload',
+        '',
+        '      docstring',
+        '',
+        '',
+        '.. py:function:: sum(x, y)',
+        '                 sum(x, y)',
+        '                 sum(x, y)',
+        '   :module: target.overload',
+        '',
+        '   docstring',
+        '',
+    ]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/autodoc/__init__\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc.py
cat coverage.cover
git checkout 2c2335bbb8af99fa132e1573bbf45dc91584d5a2
git apply /root/pre_state.patch
