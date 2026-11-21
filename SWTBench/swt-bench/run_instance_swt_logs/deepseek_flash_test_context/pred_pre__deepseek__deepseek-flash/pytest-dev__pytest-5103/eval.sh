#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 10ca84ffc56c2dd2d9dc4bd71b7b898e083500cd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 10ca84ffc56c2dd2d9dc4bd71b7b898e083500cd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_assertrewrite.py b/testing/test_assertrewrite.py
index 87dada21..4072a503 100755
--- a/testing/test_assertrewrite.py
+++ b/testing/test_assertrewrite.py
@@ -525,6 +525,26 @@ class TestAssertionRewrite(object):
  +  where False = g(**{'a': 2})"""
         )
 
+    def test_all_reports_failing_iteration(self):
+        def f():
+            def is_even(number):
+                return number % 2 == 0
+
+            assert all(is_even(number) for number in [1, 3, 5])
+
+        msg = getmsg(f)
+        assert "is_even(1)" in msg
+
+    def test_any_reports_failing_iteration(self):
+        def f():
+            def is_even(number):
+                return number % 2 == 0
+
+            assert any(is_even(number) for number in [1])
+
+        msg = getmsg(f)
+        assert "is_even(1)" in msg
+
     def test_attribute(self):
         class X(object):
             g = 3

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/assertion/rewrite\.py)' -m pytest -rA testing/test_assertrewrite.py
cat coverage.cover
git checkout 10ca84ffc56c2dd2d9dc4bd71b7b898e083500cd
git apply /root/pre_state.patch
