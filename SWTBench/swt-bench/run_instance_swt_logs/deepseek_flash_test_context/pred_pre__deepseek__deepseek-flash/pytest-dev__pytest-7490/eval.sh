#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7f7a36478abe7dd1fa993b115d22606aa0e35e88 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7f7a36478abe7dd1fa993b115d22606aa0e35e88
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_skipping.py b/testing/test_skipping.py
index 8fceb37aa..69176fa96 100755
--- a/testing/test_skipping.py
+++ b/testing/test_skipping.py
@@ -425,6 +425,18 @@ class TestXFail:
         result = testdir.runpytest(p)
         result.stdout.fnmatch_lines(["*1 xfailed*"])
 
+    def test_dynamic_xfail_set_during_test(self, testdir):
+        p = testdir.makepyfile(
+            """
+            import pytest
+            def test_this(request):
+                request.node.add_marker(pytest.mark.xfail(reason="xfail"))
+                assert 0
+        """
+        )
+        result = testdir.runpytest(p, "-rxX")
+        result.stdout.fnmatch_lines(["*XFAIL*test_this*", "*xfail*", "*1 xfailed*"])
+
     @pytest.mark.parametrize(
         "expected, actual, matchline",
         [

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/skipping\.py)' -m pytest -rA testing/test_skipping.py
cat coverage.cover
git checkout 7f7a36478abe7dd1fa993b115d22606aa0e35e88
git apply /root/pre_state.patch
