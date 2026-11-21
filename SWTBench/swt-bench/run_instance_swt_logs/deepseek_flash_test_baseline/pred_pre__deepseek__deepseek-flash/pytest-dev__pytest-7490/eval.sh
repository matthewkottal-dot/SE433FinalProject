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
index 8fceb37aa..997885744 100755
--- a/testing/test_skipping.py
+++ b/testing/test_skipping.py
@@ -203,6 +203,21 @@ class TestXFail:
         callreport = reports[1]
         assert callreport.wasxfail
 
+    def test_xfail_set_during_call(self, testdir):
+        item = testdir.getitem(
+            """
+            import pytest
+            def test_func(request):
+                request.node.add_marker(pytest.mark.xfail(reason="xfail"))
+                assert 0
+        """
+        )
+        reports = runtestprotocol(item, log=False)
+        assert len(reports) == 3
+        callreport = reports[1]
+        assert callreport.skipped
+        assert callreport.wasxfail == "xfail"
+
     def test_xfail_xpassed_strict(self, testdir):
         item = testdir.getitem(
             """

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/skipping\.py)' -m pytest -rA testing/test_skipping.py
cat coverage.cover
git checkout 7f7a36478abe7dd1fa993b115d22606aa0e35e88
git apply /root/pre_state.patch
