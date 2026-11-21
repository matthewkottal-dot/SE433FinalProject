#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 662cfb818e865f580e18b59efbb3540c34232beb >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 662cfb818e865f580e18b59efbb3540c34232beb
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_arit.py b/sympy/core/tests/test_arit.py
index 06d65203f..2504ab746 100755
--- a/sympy/core/tests/test_arit.py
+++ b/sympy/core/tests/test_arit.py
@@ -1608,6 +1608,20 @@ def test_Mod():
     assert (x**6000%400).args[1] == 400
 
 
+def test_Mod_noninteger_base():
+    # A power only reduces to zero modulo its base if the base is known
+    # to be an integer.  Otherwise the unevaluated expression must be kept
+    # so that substitution uses the actual value of the base.
+    assert Mod(x**2, x).func is Mod
+    assert Mod(x**2, x) != 0
+    assert Mod(x**2, x).subs(x, 1.5) == Mod(S(1.5)**2, S(1.5))
+    assert Mod(x**2, x).subs(x, 1.5) == S(3)/4
+
+    # The simplification remains valid for an integer base.
+    i = Symbol('i', integer=True)
+    assert Mod(i**2, i) == 0
+
+
 def test_Mod_is_integer():
     p = Symbol('p', integer=True)
     q1 = Symbol('q1', integer=True)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/mod\.py)' bin/test -C --verbose sympy/core/tests/test_arit.p
cat coverage.cover
git checkout 662cfb818e865f580e18b59efbb3540c34232beb
git apply /root/pre_state.patch
