#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2f7415cfbc4b6ca62f9013f1abd27136f46b9653 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2f7415cfbc4b6ca62f9013f1abd27136f46b9653
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/src/_pytest/pathlib.py b/src/_pytest/pathlib.py
--- a/src/_pytest/pathlib.py
+++ b/src/_pytest/pathlib.py
@@ -523,6 +523,8 @@ def import_path(
 
     if mode is ImportMode.importlib:
         module_name = module_name_from_path(path, root)
+        with contextlib.suppress(KeyError):
+            return sys.modules[module_name]
 
         for meta_importer in sys.meta_path:
             spec = meta_importer.find_spec(module_name, [str(path.parent)])

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_doctest.py b/testing/test_doctest.py
index f189e8645..26638ff28 100755
--- a/testing/test_doctest.py
+++ b/testing/test_doctest.py
@@ -135,6 +135,45 @@ class TestDoctests:
         reprec = pytester.inline_run("--doctest-modules", "--import-mode=importlib")
         reprec.assertoutcome(passed=1)
 
+    def test_importmode_importlib_does_not_reimport_package_modules(
+        self, pytester: Pytester
+    ) -> None:
+        """Modules imported during collection must not replace existing instances."""
+        pytester.makeini(
+            """
+            [pytest]
+            pythonpath = .
+            """
+        )
+        pytester.makepyfile(
+            **{
+                "pkg/__init__.py": "from . import logging\n",
+                "pkg/core.py": """
+                    from . import logging
+
+                    def initialize():
+                        logging.Logger.store = object()
+                """,
+                "pkg/logging.py": """
+                    class Logger:
+                        store = None
+                """,
+                "tests/test_commands.py": """
+                    import sys
+
+                    from pkg import core
+                    from pkg import logging
+
+                    def test_initialize():
+                        core.initialize()
+                        assert logging is sys.modules["pkg.logging"]
+                        assert logging.Logger.store is not None
+                """,
+            }
+        )
+        result = pytester.runpytest("--doctest-modules", "--import-mode=importlib")
+        result.assert_outcomes(passed=1)
+
     def test_new_pattern(self, pytester: Pytester):
         p = pytester.maketxtfile(
             xdoc="""

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/pathlib\.py)' -m pytest -rA testing/test_doctest.py
cat coverage.cover
git checkout 2f7415cfbc4b6ca62f9013f1abd27136f46b9653
git apply /root/pre_state.patch
