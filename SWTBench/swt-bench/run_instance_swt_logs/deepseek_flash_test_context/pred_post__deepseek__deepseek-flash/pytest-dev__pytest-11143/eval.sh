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
index d01803204..4369d0750 100755
--- a/testing/test_assertrewrite.py
+++ b/testing/test_assertrewrite.py
@@ -113,6 +113,22 @@ class TestAssertionRewrite:
             assert imp.col_offset == 0
         assert isinstance(m.body[3], ast.Expr)
 
+    @pytest.mark.parametrize("first_statement", ["42", "None", "True", "b'bytes'"])
+    def test_first_statement_is_not_a_docstring(
+        self, first_statement: str, pytester: Pytester
+    ) -> None:
+        """Non-string constants must not be treated as module docstrings."""
+        pytester.makepyfile(
+            f"""
+            {first_statement}
+
+            def test_rewritten():
+                assert 1 == 1
+            """
+        )
+        result = pytester.runpytest()
+        result.assert_outcomes(passed=1)
+
     def test_location_is_set(self) -> None:
         s = textwrap.dedent(
             """

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/assertion/rewrite\.py)' -m pytest -rA testing/test_assertrewrite.py
cat coverage.cover
git checkout 6995257cf470d2143ad1683824962de4071c0eb7
git apply /root/pre_state.patch
