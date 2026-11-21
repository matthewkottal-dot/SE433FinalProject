#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c087d717f6ed183dd422359bf91210dc59689d63 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c087d717f6ed183dd422359bf91210dc59689d63
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/ext/napoleon/docstring.py b/sphinx/ext/napoleon/docstring.py
--- a/sphinx/ext/napoleon/docstring.py
+++ b/sphinx/ext/napoleon/docstring.py
@@ -318,7 +318,7 @@ def _dedent(self, lines: List[str], full: bool = False) -> List[str]:
             return [line[min_indent:] for line in lines]
 
     def _escape_args_and_kwargs(self, name: str) -> str:
-        if name.endswith('_'):
+        if name.endswith('_') and getattr(self._config, 'strip_signature_backslash', False):
             name = name[:-1] + r'\_'
 
         if name[:2] == '**':

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_napoleon_docstring.py b/tests/test_ext_napoleon_docstring.py
index 3027a4cb2..3f3ec9e85 100755
--- a/tests/test_ext_napoleon_docstring.py
+++ b/tests/test_ext_napoleon_docstring.py
@@ -1037,6 +1037,25 @@ Sooper Warning:
             actual = str(GoogleDocstring(docstring, testConfig))
             self.assertEqual(expected, actual)
 
+    def test_underscore_in_attribute(self):
+        docstring = """\
+Attributes:
+    arg_ (type): some description
+"""
+
+        expected = """\
+.. attribute:: arg_
+   :type: type
+
+   some description
+"""
+
+        config = Config()
+        app = mock.Mock()
+        actual = str(GoogleDocstring(docstring, config, app, "class"))
+
+        self.assertEqual(expected, actual)
+
     def test_noindex(self):
         docstring = """
 Attributes:
@@ -1409,6 +1428,28 @@ arg_ : type
 
         self.assertEqual(expected, actual)
 
+    def test_underscore_in_attribute_without_ivar(self):
+        docstring = """\
+Attributes
+----------
+
+arg_ : type
+    some description
+"""
+
+        expected = """\
+.. attribute:: arg_
+   :type: type
+
+   some description
+"""
+
+        config = Config(napoleon_use_ivar=False)
+        app = mock.Mock()
+        actual = str(NumpyDocstring(docstring, config, app, "class"))
+
+        self.assertEqual(expected, actual)
+
     def test_raises_types(self):
         docstrings = [("""
 Example Function

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/napoleon/docstring\.py)' -m tox -epy39 -v -- tests/test_ext_napoleon_docstring.py
cat coverage.cover
git checkout c087d717f6ed183dd422359bf91210dc59689d63
git apply /root/pre_state.patch
