#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5c2e1f96a7ff562d4a778f4ca9ffc9c81557197e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5c2e1f96a7ff562d4a778f4ca9ffc9c81557197e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/functions/elementary/trigonometric.py b/sympy/functions/elementary/trigonometric.py
--- a/sympy/functions/elementary/trigonometric.py
+++ b/sympy/functions/elementary/trigonometric.py
@@ -16,6 +16,8 @@
 from sympy.sets.sets import FiniteSet
 from sympy.utilities.iterables import numbered_symbols
 from sympy.core.compatibility import range
+from sympy.core.relational import Ne
+from sympy.functions.elementary.piecewise import Piecewise
 
 ###############################################################################
 ########################## TRIGONOMETRIC FUNCTIONS ############################
@@ -400,6 +402,9 @@ def _eval_rewrite_as_csc(self, arg):
     def _eval_rewrite_as_sec(self, arg):
         return 1 / sec(arg - S.Pi / 2, evaluate=False)
 
+    def _eval_rewrite_as_sinc(self, arg):
+        return arg*sinc(arg)
+
     def _eval_conjugate(self):
         return self.func(self.args[0].conjugate())
 
@@ -1789,7 +1794,7 @@ def _eval_rewrite_as_jn(self, arg):
         return jn(0, arg)
 
     def _eval_rewrite_as_sin(self, arg):
-        return sin(arg) / arg
+        return Piecewise((sin(arg)/arg, Ne(arg, 0)), (1, True))
 
 
 ###############################################################################

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/simplify/tests/test_trigsimp.py b/sympy/simplify/tests/test_trigsimp.py
index 67694b477..f1269d260 100755
--- a/sympy/simplify/tests/test_trigsimp.py
+++ b/sympy/simplify/tests/test_trigsimp.py
@@ -1,7 +1,7 @@
 from sympy import (
     symbols, sin, simplify, cos, trigsimp, rad, tan, exptrigsimp,sinh,
     cosh, diff, cot, Subs, exp, tanh, exp, S, integrate, I,Matrix,
-    Symbol, coth, pi, log, count_ops, sqrt, E, expand, Piecewise)
+    Symbol, coth, pi, log, count_ops, sqrt, E, expand, Piecewise, sinc)
 
 from sympy.utilities.pytest import XFAIL
 
@@ -400,6 +400,16 @@ def valid(a, b):
         assert valid(s, 2*sinh(a))
 
 
+def test_exponential_to_trig():
+    k = Symbol('k')
+    e = S(1)/2*(-I*exp(I*k) + I*exp(-I*k))
+    assert trigsimp(e) == sin(k) or exptrigsimp(e) == sin(k)
+
+    e = e/k
+    candidates = (trigsimp(e), exptrigsimp(e))
+    assert any(c in (sin(k)/k, sinc(k)) for c in candidates)
+
+
 def test_powsimp_on_numbers():
     assert 2**(S(1)/3 - 2) == 2**(S(1)/3)/4
 

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/functions/elementary/trigonometric\.py)' bin/test -C --verbose sympy/simplify/tests/test_trigsimp.p
cat coverage.cover
git checkout 5c2e1f96a7ff562d4a778f4ca9ffc9c81557197e
git apply /root/pre_state.patch
