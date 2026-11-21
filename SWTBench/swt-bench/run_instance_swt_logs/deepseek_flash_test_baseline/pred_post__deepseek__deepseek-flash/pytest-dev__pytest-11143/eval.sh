#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6995257cf470d2143ad1683824962de4071c0eb7 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6995257cf470d2143ad1683824962de4071c0eb7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/src/_pytest/assertion/rewrite.py b/src/_pytest/assertion/rewrite.py
--- a/src/_pytest/assertion/rewrite.py
+++ b/src/_pytest/assertion/rewrite.py
@@ -676,6 +676,7 @@ def run(self, mod: ast.Module) -> None:
                 expect_docstring
                 and isinstance(item, ast.Expr)
                 and isinstance(item.value, ast.Constant)
+                and isinstance(item.value.value, str)
             ):
                 doc = item.value.value
                 if self.is_rewrite_disabled(doc):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_assertrewrite.py b/testing/test_assertrewrite.py
index d01803204..be07957bb 100755
--- a/testing/test_assertrewrite.py
+++ b/testing/test_assertrewrite.py
@@ -141,6 +141,11 @@ class TestAssertionRewrite:
         assert isinstance(m.body[1], ast.Assert)
         assert m.body[1].msg is None
 
+    def test_non_string_first_expression_is_not_docstring(self) -> None:
+        s = """1\nassert 1 == 2"""
+        m = rewrite(s)
+        assert not any(isinstance(node, ast.Assert) for node in ast.walk(m))
+
     def test_dont_rewrite_plugin(self, pytester: Pytester) -> None:
         contents = {
             "conftest.py": "pytest_plugins = 'plugin'; import plugin",
@@ -727,6 +732,19 @@ class TestAssertionRewrite:
 
 
 class TestRewriteOnImport:
+    def test_first_expression_is_not_a_docstring(self, pytester: Pytester) -> None:
+        pytester.makepyfile(
+            """
+            1
+
+            def test_fails():
+                assert 1 == 2
+            """
+        )
+        result = pytester.runpytest()
+        result.assert_outcomes(failed=1)
+        result.stdout.fnmatch_lines(["*assert 1 == 2*"])
+
     def test_pycache_is_a_file(self, pytester: Pytester) -> None:
         pytester.path.joinpath("__pycache__").write_text("Hello", encoding="utf-8")
         pytester.makepyfile(

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/assertion/rewrite\.py)' -m pytest -rA testing/test_assertrewrite.py
cat coverage.cover
git checkout 6995257cf470d2143ad1683824962de4071c0eb7
git apply /root/pre_state.patch
