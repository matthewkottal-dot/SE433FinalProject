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
diff --git a/sympy/printing/tests/test_latex.py b/sympy/printing/tests/test_latex.py
index 8a7054905..9aa77a4b5 100755
--- a/sympy/printing/tests/test_latex.py
+++ b/sympy/printing/tests/test_latex.py
@@ -994,6 +994,15 @@ def test_latex_pow_fraction():
     assert '3^{-x}' in latex(3**-x/2).replace(' ', '')
 
 
+def test_latex_mul_negative_irrational_power():
+    # The pretty printer leaves negative non-rational powers in the numerator.
+    # The LaTeX printer should do the same rather than moving them into the
+    # denominator.
+    assert latex(2*x**(-pi)) == r"2 x^{- \pi}"
+    assert latex(2*x**(-sqrt(2))) == r"2 x^{- \sqrt{2}}"
+    assert latex(2*(x + y)**(-pi)) == r"2 \left(x + y\right)^{- \pi}"
+
+
 def test_noncommutative():
     A, B, C = symbols('A,B,C', commutative=False)
 

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/latex\.py)' bin/test -C --verbose sympy/printing/tests/test_latex.p
cat coverage.cover
git checkout e2918c1205c47345eb73c9be68b14c0f15fdeb17
git apply /root/pre_state.patch
