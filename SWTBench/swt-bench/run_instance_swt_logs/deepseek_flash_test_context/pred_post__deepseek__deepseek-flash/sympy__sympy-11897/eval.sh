#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e2918c1205c47345eb73c9be68b14c0f15fdeb17 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e2918c1205c47345eb73c9be68b14c0f15fdeb17
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/latex.py b/sympy/printing/latex.py
--- a/sympy/printing/latex.py
+++ b/sympy/printing/latex.py
@@ -235,10 +235,12 @@ def _needs_mul_brackets(self, expr, first=False, last=False):
         elif expr.is_Mul:
             if not first and _coeff_isneg(expr):
                 return True
+        if expr.is_Piecewise:
+            return True
         if any([expr.has(x) for x in (Mod,)]):
             return True
         if (not last and
-            any([expr.has(x) for x in (Integral, Piecewise, Product, Sum)])):
+            any([expr.has(x) for x in (Integral, Product, Sum)])):
             return True
 
         return False

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_latex.py b/sympy/printing/tests/test_latex.py
index 8a7054905..9a50abb00 100755
--- a/sympy/printing/tests/test_latex.py
+++ b/sympy/printing/tests/test_latex.py
@@ -867,10 +867,26 @@ def test_latex_Piecewise():
     p = Piecewise((A**2, Eq(A, B)), (A*B, True))
     s = r"\begin{cases} A^{2} & \text{for}\: A = B \\A B & \text{otherwise} \end{cases}"
     assert latex(p) == s
-    assert latex(A*p) == r"A %s" % s
+    assert latex(A*p) == r"A \left(%s\right)" % s
     assert latex(p*A) == r"\left(%s\right) A" % s
 
 
+def test_latex_Piecewise_mul():
+    # A Piecewise multiplied by other factors must be parenthesized to
+    # match the pretty printer's output (issue 11275).
+    p = Piecewise((x, x < 0), (0, True))
+    expected = r"2 \left(\begin{cases} x & \text{for}\: x < 0 \\0 & \text{otherwise} \end{cases}\right)"
+    assert latex(2*p) == expected
+
+    p = Piecewise(((-1)**Rational(2, 3), 3*x/4 < 0), (1, True))
+    expr = 6**Rational(1, 3)*x**Rational(1, 3)*p
+    assert latex(FiniteSet(expr)) == (
+        r"\left\{\sqrt[3]{6} \sqrt[3]{x} "
+        r"\left(\begin{cases} \left(-1\right)^{\frac{2}{3}} & "
+        r"\text{for}\: \frac{3 x}{4} < 0 \\1 & \text{otherwise} "
+        r"\end{cases}\right)\right\}")
+
+
 def test_latex_Matrix():
     M = Matrix([[1 + x, y], [y, x - 1]])
     assert latex(M) == \

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/latex\.py)' bin/test -C --verbose sympy/printing/tests/test_latex.p
cat coverage.cover
git checkout e2918c1205c47345eb73c9be68b14c0f15fdeb17
git apply /root/pre_state.patch
