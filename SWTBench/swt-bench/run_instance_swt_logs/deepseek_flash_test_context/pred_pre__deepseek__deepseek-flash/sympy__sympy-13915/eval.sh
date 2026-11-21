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
diff --git a/sympy/core/tests/test_subs.py b/sympy/core/tests/test_subs.py
index 90abb9e37..f36b4423a 100755
--- a/sympy/core/tests/test_subs.py
+++ b/sympy/core/tests/test_subs.py
@@ -779,3 +779,12 @@ def test_issue_12657():
     reps = [(-oo, 2), (oo, 1)]
     assert (x < oo).subs(reps) == (x < 1)
     assert (x < oo).subs(list(reversed(reps))) == (x < 1)
+
+
+def test_undefined_result_after_substitution():
+    # Substituting b -> a makes individual terms undefined.  The result
+    # should therefore be nan rather than simplifying to 1 by cancelling
+    # two equal-looking undefined subexpressions.
+    a, b = symbols('a b')
+    r = (1/(a + b) + 1/(a - b))/(1/(a + b) - 1/(a - b))
+    assert r.subs(b, a) is S.NaN

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/mul\.py)' bin/test -C --verbose sympy/core/tests/test_subs.p
cat coverage.cover
git checkout 5c1644ff85e15752f9f8721bc142bfbf975e7805
git apply /root/pre_state.patch
