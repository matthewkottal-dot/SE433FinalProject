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
diff --git a/src/_pytest/nodes.py b/src/_pytest/nodes.py
--- a/src/_pytest/nodes.py
+++ b/src/_pytest/nodes.py
@@ -29,6 +29,7 @@
 from _pytest.mark.structures import MarkDecorator
 from _pytest.mark.structures import NodeKeywords
 from _pytest.outcomes import fail
+from _pytest.pathlib import Path
 from _pytest.store import Store
 
 if TYPE_CHECKING:
@@ -361,9 +362,14 @@ def _repr_failure_py(
         else:
             truncate_locals = True
 
+        # excinfo.getrepr() formats paths relative to the CWD if `abspath` is False.
+        # It is possible for a fixture/test to change the CWD while this code runs, which
+        # would then result in the user seeing confusing paths in the failure message.
+        # To fix this, if the CWD changed, always display the full absolute path.
+        # It will be better to just always display paths relative to invocation_dir, but
+        # this requires a lot of plumbing (#6428).
         try:
-            os.getcwd()
-            abspath = False
+            abspath = Path(os.getcwd()) != Path(self.config.invocation_dir)
         except OSError:
             abspath = True
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_traceback_path.py b/testing/test_traceback_path.py
new file mode 100644
index 000000000..d7a7ceff8
--- /dev/null
+++ b/testing/test_traceback_path.py
@@ -0,0 +1,30 @@
+def test_traceback_path_unaffected_by_fixture_chdir(testdir):
+    """A traceback path should be relative to the invocation directory.
+
+    The current working directory may be changed by a fixture while the test
+    runs; that should not alter how the failing test's path is displayed.
+    """
+    testdir.makepyfile(
+        test_path_error="""
+        import os
+
+        import pytest
+
+
+        @pytest.fixture
+        def private_dir():
+            out_dir = "ddd"
+            os.mkdir(out_dir)
+            old_dir = os.getcwd()
+            os.chdir(out_dir)
+            yield out_dir
+            os.chdir(old_dir)
+
+
+        def test_show_wrong_path(private_dir):
+            assert False
+        """
+    )
+    result = testdir.runpytest()
+    result.stdout.fnmatch_lines(["test_path_error.py:*: AssertionError"])
+    result.stdout.no_fnmatch_line("../test_path_error.py:*")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/nodes\.py)' -m pytest -rA testing/test_traceback_path.py
cat coverage.cover
git checkout 56bf819c2f4eaf8b36bd8c42c06bb59d5a3bfc0f
git apply /root/pre_state.patch
