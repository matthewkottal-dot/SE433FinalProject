#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5c1644ff85e15752f9f8721bc142bfbf975e7805 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5c1644ff85e15752f9f8721bc142bfbf975e7805
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/mul.py b/sympy/core/mul.py
--- a/sympy/core/mul.py
+++ b/sympy/core/mul.py
@@ -423,6 +423,11 @@ def _gather(c_powers):
             changed = False
             for b, e in c_powers:
                 if e.is_zero:
+                    # canceling out infinities yields NaN
+                    if (b.is_Add or b.is_Mul) and any(infty in b.args
+                        for infty in (S.ComplexInfinity, S.Infinity,
+                                      S.NegativeInfinity)):
+                        return [S.NaN], [], None
                     continue
                 if e is S.One:
                     if b.is_Number:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_subs.py b/sympy/core/tests/test_subs.py
index 90abb9e37..4efa2e1ee 100755
--- a/sympy/core/tests/test_subs.py
+++ b/sympy/core/tests/test_subs.py
@@ -779,3 +779,12 @@ def test_issue_12657():
     reps = [(-oo, 2), (oo, 1)]
     assert (x < oo).subs(reps) == (x < 1)
     assert (x < oo).subs(list(reversed(reps))) == (x < 1)
+
+
+def test_subs_undefined():
+    # Substituting b = a makes both the numerator and denominator of this
+    # expression undefined.  The substitution must not incorrectly simplify
+    # the expression to 1.
+    a, b = symbols('a b')
+    r = (1/(a + b) + 1/(a - b))/(1/(a + b) - 1/(a - b))
+    assert r.subs(b, a) is not S.One

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/mul\.py)' bin/test -C --verbose sympy/core/tests/test_subs.p
cat coverage.cover
git checkout 5c1644ff85e15752f9f8721bc142bfbf975e7805
git apply /root/pre_state.patch
