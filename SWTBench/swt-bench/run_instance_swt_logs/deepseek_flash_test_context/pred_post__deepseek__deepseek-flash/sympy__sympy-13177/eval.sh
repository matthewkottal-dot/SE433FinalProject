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
diff --git a/sympy/core/mod.py b/sympy/core/mod.py
--- a/sympy/core/mod.py
+++ b/sympy/core/mod.py
@@ -39,7 +39,8 @@ def doit(p, q):
             if p.is_infinite or q.is_infinite or p is nan or q is nan:
                 return nan
             if (p == q or p == -q or
-                    p.is_Pow and p.exp.is_Integer and p.base == q or
+                    p.is_Pow and p.exp.is_integer and p.base == q and q.is_integer
+                    and p.exp.is_positive or
                     p.is_integer and q == 1):
                 return S.Zero
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_arit.py b/sympy/core/tests/test_arit.py
index 06d65203f..1a9b4726f 100755
--- a/sympy/core/tests/test_arit.py
+++ b/sympy/core/tests/test_arit.py
@@ -1607,6 +1607,12 @@ def test_Mod():
     # issue 10963
     assert (x**6000%400).args[1] == 400
 
+    # x**2 % x is only zero when x is an integer
+    assert Mod(x**2, x).subs(x, S(3)/2) == S(3)/4
+    assert Mod(x**2, x) != 0
+    xi = Symbol('xi', integer=True)
+    assert Mod(xi**2, xi) == 0
+
 
 def test_Mod_is_integer():
     p = Symbol('p', integer=True)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/mod\.py)' bin/test -C --verbose sympy/core/tests/test_arit.p
cat coverage.cover
git checkout 662cfb818e865f580e18b59efbb3540c34232beb
git apply /root/pre_state.patch
