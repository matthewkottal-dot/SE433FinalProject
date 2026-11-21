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
diff --git a/sympy/simplify/tests/test_trigsimp.py b/sympy/simplify/tests/test_trigsimp.py
index 67694b477..28319c4ef 100755
--- a/sympy/simplify/tests/test_trigsimp.py
+++ b/sympy/simplify/tests/test_trigsimp.py
@@ -426,3 +426,23 @@ def test_Piecewise():
     # trigsimp tries not to touch non-trig containing args
     assert trigsimp(Piecewise((e1, e3 < e2), (e3, True))) == \
         Piecewise((e1, e3 < s2), (e3, True))
+
+
+def test_exponential_to_trig():
+    k = Symbol('k')
+    f = S.Half*(-I*exp(I*k) + I*exp(-I*k))
+
+    # The expression should reduce to sin(k) using either the general
+    # trigonometric simplifier or the dedicated exponential/trig simplifier.
+    r = trigsimp(f)
+    if r != sin(k):
+        r = exptrigsimp(f)
+    assert r == sin(k)
+
+    # As in the issue, the same identity divided by k should reduce to
+    # sin(k)/k (possibly expressed as the equivalent sinc(k)).
+    f = f/k
+    r = trigsimp(f)
+    if r.rewrite(sin) != sin(k)/k:
+        r = exptrigsimp(f)
+    assert r.rewrite(sin) == sin(k)/k

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/functions/elementary/trigonometric\.py)' bin/test -C --verbose sympy/simplify/tests/test_trigsimp.p
cat coverage.cover
git checkout 5c2e1f96a7ff562d4a778f4ca9ffc9c81557197e
git apply /root/pre_state.patch
