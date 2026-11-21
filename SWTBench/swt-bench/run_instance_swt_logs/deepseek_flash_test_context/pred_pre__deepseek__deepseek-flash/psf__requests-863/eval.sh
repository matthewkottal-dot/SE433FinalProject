#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a0df2cbb10419037d11d04352b3175405ab52941 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a0df2cbb10419037d11d04352b3175405ab52941
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_requests.py b/tests/test_requests.py
index f8a31f2..22172dc 100755
--- a/tests/test_requests.py
+++ b/tests/test_requests.py
@@ -710,6 +710,18 @@ class RequestsTestSuite(TestSetup, TestBaseMixin, unittest.TestCase):
 
             assert 'foo' in response.text
 
+    def test_multiple_hooks_are_parsed_from_hooks_dict(self):
+        def first_hook(args):
+            return args
+
+        def second_hook(args):
+            return args
+
+        request = requests.Request(
+            'http://example.com/', hooks={'args': [first_hook, second_hook]})
+
+        self.assertEqual(request.hooks['args'], [first_hook, second_hook])
+
     def test_multiple_hooks(self):
 
         def add_foo_header(args):

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/models\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_requests.py
cat coverage.cover
git checkout a0df2cbb10419037d11d04352b3175405ab52941
git apply /root/pre_state.patch
