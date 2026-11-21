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
index 87dada21..3c149688 100755
--- a/testing/test_assertrewrite.py
+++ b/testing/test_assertrewrite.py
@@ -525,6 +525,21 @@ class TestAssertionRewrite(object):
  +  where False = g(**{'a': 2})"""
         )
 
+    def test_all_generator_unrolled(self):
+        class FailingItem(object):
+            def __repr__(self):
+                return "<FAILING_ITEM>"
+
+        def predicate(item):
+            return False
+
+        def f():
+            items = [failing_item]
+            assert all(predicate(item) for item in items)
+
+        msg = getmsg(f, {"failing_item": FailingItem(), "predicate": predicate})
+        assert "<FAILING_ITEM>" in msg
+
     def test_attribute(self):
         class X(object):
             g = 3

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/assertion/rewrite\.py)' -m pytest -rA testing/test_assertrewrite.py
cat coverage.cover
git checkout 10ca84ffc56c2dd2d9dc4bd71b7b898e083500cd
git apply /root/pre_state.patch
