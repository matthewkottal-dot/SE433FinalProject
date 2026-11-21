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
diff --git a/testing/test_doctest.py b/testing/test_doctest.py
index f189e8645..47ae30e7b 100755
--- a/testing/test_doctest.py
+++ b/testing/test_doctest.py
@@ -135,6 +135,48 @@ class TestDoctests:
         reprec = pytester.inline_run("--doctest-modules", "--import-mode=importlib")
         reprec.assertoutcome(passed=1)
 
+    def test_importmode_importlib_module_imported_once(
+        self, pytester: Pytester
+    ) -> None:
+        """
+        Modules imported before doctest collection should not be imported again
+        by ``--import-mode=importlib``, otherwise references to the previous
+        module object become stale.
+        """
+        pytester.makeini(
+            """
+            [pytest]
+            pythonpath = .
+            """
+        )
+        pytester.makepyfile(
+            **{
+                "conftest.py": """
+                    import mypkg.mod
+                """,
+                "mypkg/__init__.py": "",
+                "mypkg/mod.py": '''
+                    def add(a, b):
+                        """
+                        >>> add(1, 2)
+                        3
+                        """
+                        return a + b
+                ''',
+                "test_identity.py": """
+                    import sys
+                    import mypkg.mod
+
+                    def test_identity():
+                        assert sys.modules["mypkg.mod"] is mypkg.mod
+                """,
+            }
+        )
+        result = pytester.runpytest(
+            "--doctest-modules", "--import-mode=importlib", "-v"
+        )
+        result.assert_outcomes(passed=2)
+
     def test_new_pattern(self, pytester: Pytester):
         p = pytester.maketxtfile(
             xdoc="""

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/pathlib\.py)' -m pytest -rA testing/test_doctest.py
cat coverage.cover
git checkout 2f7415cfbc4b6ca62f9013f1abd27136f46b9653
git apply /root/pre_state.patch
