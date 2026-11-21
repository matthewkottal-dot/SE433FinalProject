#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d3fcdb72bfcbb560eb45264ac1c03f359436edef >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d3fcdb72bfcbb560eb45264ac1c03f359436edef
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/matrices/matrices.py b/sympy/matrices/matrices.py
--- a/sympy/matrices/matrices.py
+++ b/sympy/matrices/matrices.py
@@ -641,7 +641,7 @@ def _eval_is_zero(self):
     def _eval_is_upper_hessenberg(self):
         return all(self[i, j].is_zero
                    for i in range(2, self.rows)
-                   for j in range(i - 1))
+                   for j in range(min(self.cols, (i - 1))))
 
     def _eval_values(self):
         return [i for i in self if not i.is_zero]
@@ -1112,7 +1112,7 @@ def is_upper(self):
         """
         return all(self[i, j].is_zero
                    for i in range(1, self.rows)
-                   for j in range(i))
+                   for j in range(min(i, self.cols)))
 
     @property
     def is_zero(self):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/matrices/tests/test_commonmatrix.py b/sympy/matrices/tests/test_commonmatrix.py
index 757467198..a745f9968 100755
--- a/sympy/matrices/tests/test_commonmatrix.py
+++ b/sympy/matrices/tests/test_commonmatrix.py
@@ -293,6 +293,8 @@ def test_is_upper():
     assert a.is_upper is True
     a = PropertiesOnlyMatrix([[1], [2], [3]])
     assert a.is_upper is False
+    a = PropertiesOnlyMatrix(4, 2, lambda i, j: 0)
+    assert a.is_upper is True
 
 
 def test_is_lower():
diff --git a/sympy/matrices/tests/test_matrices.py b/sympy/matrices/tests/test_matrices.py
index 03b1548fd..33ab4bbb8 100755
--- a/sympy/matrices/tests/test_matrices.py
+++ b/sympy/matrices/tests/test_matrices.py
@@ -1225,6 +1225,8 @@ def test_is_upper():
     assert a.is_upper is True
     a = Matrix([[1], [2], [3]])
     assert a.is_upper is False
+    a = zeros(4, 2)
+    assert a.is_upper is True
 
 
 def test_is_lower():

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/matrices/matrices\.py)' bin/test -C --verbose sympy/matrices/tests/test_commonmatrix.py sympy/matrices/tests/test_matrices.p
cat coverage.cover
git checkout d3fcdb72bfcbb560eb45264ac1c03f359436edef
git apply /root/pre_state.patch
