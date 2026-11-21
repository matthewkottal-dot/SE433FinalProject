#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b678d8103e48fdb1af335dbf0080b3d5366f2d17 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b678d8103e48fdb1af335dbf0080b3d5366f2d17
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/operations.py b/sympy/core/operations.py
--- a/sympy/core/operations.py
+++ b/sympy/core/operations.py
@@ -332,9 +332,7 @@ def _eval_evalf(self, prec):
                         args.append(a)
                     else:
                         args.append(newa)
-                if not _aresame(tuple(args), tail_args):
-                    tail = self.func(*args)
-                return self.func(x, tail)
+                return self.func(x, *args)
 
         # this is the same as above, but there were no pure-number args to
         # deal with
@@ -345,9 +343,7 @@ def _eval_evalf(self, prec):
                 args.append(a)
             else:
                 args.append(newa)
-        if not _aresame(tuple(args), self.args):
-            return self.func(*args)
-        return self
+        return self.func(*args)
 
     @classmethod
     def make_args(cls, expr):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/simplify/tests/test_simplify.py b/sympy/simplify/tests/test_simplify.py
index 6acf69000..2d4082dc4 100755
--- a/sympy/simplify/tests/test_simplify.py
+++ b/sympy/simplify/tests/test_simplify.py
@@ -652,3 +652,10 @@ def test_clear_coefficients():
     assert clear_coefficients(S.Infinity, x) == (S.Infinity, x)
     assert clear_coefficients(-S.Pi, x) == (S.Pi, -x)
     assert clear_coefficients(2 - S.Pi/3, x) == (pi, -3*x + 6)
+
+
+def test_simplify_float_exponent_of_different_precision():
+    # simplify should recognize that the two numerically evaluated terms
+    # cancel even though their exponents have different Float precisions
+    res = S(1)/2*x**2.5 - S(1)*x**(S(5)/2)/2
+    assert simplify(res.evalf(5)) == 0

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/operations\.py)' bin/test -C --verbose sympy/simplify/tests/test_simplify.p
cat coverage.cover
git checkout b678d8103e48fdb1af335dbf0080b3d5366f2d17
git apply /root/pre_state.patch
