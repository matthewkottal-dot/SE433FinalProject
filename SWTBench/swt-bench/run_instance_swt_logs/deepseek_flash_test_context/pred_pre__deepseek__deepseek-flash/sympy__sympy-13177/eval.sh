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
