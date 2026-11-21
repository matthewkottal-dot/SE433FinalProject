#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 56bf819c2f4eaf8b36bd8c42c06bb59d5a3bfc0f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 56bf819c2f4eaf8b36bd8c42c06bb59d5a3bfc0f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_terminal.py b/testing/test_terminal.py
index 0f5b4cb68..80c16fb60 100755
--- a/testing/test_terminal.py
+++ b/testing/test_terminal.py
@@ -2177,3 +2177,28 @@ class TestCodeHighlight:
                 ]
             )
         )
+
+
+def test_failure_path_after_fixture_chdir(testdir):
+    """The failure path should be relative to the original working directory."""
+    testdir.makepyfile(
+        test_path_error="""
+        import os
+
+        import pytest
+
+        @pytest.fixture
+        def change_dir():
+            old_dir = os.getcwd()
+            os.mkdir("subdir")
+            os.chdir("subdir")
+            yield
+            os.chdir(old_dir)
+
+        def test_failure(change_dir):
+            assert False
+        """
+    )
+    result = testdir.runpytest()
+    result.stdout.fnmatch_lines(["test_path_error.py:*: AssertionError"])
+    result.stdout.no_fnmatch_line("*../test_path_error.py:*")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/nodes\.py)' -m pytest -rA testing/test_terminal.py
cat coverage.cover
git checkout 56bf819c2f4eaf8b36bd8c42c06bb59d5a3bfc0f
git apply /root/pre_state.patch
