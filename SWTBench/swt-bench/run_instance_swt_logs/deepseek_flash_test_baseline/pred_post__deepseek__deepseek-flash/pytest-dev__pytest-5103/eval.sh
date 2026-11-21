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
diff --git a/src/_pytest/assertion/rewrite.py b/src/_pytest/assertion/rewrite.py
--- a/src/_pytest/assertion/rewrite.py
+++ b/src/_pytest/assertion/rewrite.py
@@ -964,6 +964,8 @@ def visit_Call_35(self, call):
         """
         visit `ast.Call` nodes on Python3.5 and after
         """
+        if isinstance(call.func, ast.Name) and call.func.id == "all":
+            return self._visit_all(call)
         new_func, func_expl = self.visit(call.func)
         arg_expls = []
         new_args = []
@@ -987,6 +989,27 @@ def visit_Call_35(self, call):
         outer_expl = "%s\n{%s = %s\n}" % (res_expl, res_expl, expl)
         return res, outer_expl
 
+    def _visit_all(self, call):
+        """Special rewrite for the builtin all function, see #5062"""
+        if not isinstance(call.args[0], (ast.GeneratorExp, ast.ListComp)):
+            return
+        gen_exp = call.args[0]
+        assertion_module = ast.Module(
+            body=[ast.Assert(test=gen_exp.elt, lineno=1, msg="", col_offset=1)]
+        )
+        AssertionRewriter(module_path=None, config=None).run(assertion_module)
+        for_loop = ast.For(
+            iter=gen_exp.generators[0].iter,
+            target=gen_exp.generators[0].target,
+            body=assertion_module.body,
+            orelse=[],
+        )
+        self.statements.append(for_loop)
+        return (
+            ast.Num(n=1),
+            "",
+        )  # Return an empty expression, all the asserts are in the for_loop
+
     def visit_Starred(self, starred):
         # From Python 3.5, a Starred node can appear in a function call
         res, expl = self.visit(starred.value)
@@ -997,6 +1020,8 @@ def visit_Call_legacy(self, call):
         """
         visit `ast.Call nodes on 3.4 and below`
         """
+        if isinstance(call.func, ast.Name) and call.func.id == "all":
+            return self._visit_all(call)
         new_func, func_expl = self.visit(call.func)
         arg_expls = []
         new_args = []

EOF_114329324912
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
