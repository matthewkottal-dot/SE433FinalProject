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
index f8a31f2..8c4b0ca 100755
--- a/tests/test_requests.py
+++ b/tests/test_requests.py
@@ -19,6 +19,7 @@ from requests import HTTPError
 from requests import get, post, head, put
 from requests.auth import HTTPBasicAuth, HTTPDigestAuth
 from requests.exceptions import InvalidURL
+from requests.hooks import dispatch_hook
 
 if 'HTTPBIN_URL' not in os.environ:
     os.environ['HTTPBIN_URL'] = 'http://httpbin.org/'
@@ -744,6 +745,30 @@ class RequestsTestSuite(TestSetup, TestBaseMixin, unittest.TestCase):
             assert 'foo' in response.text
             assert 'bar' in response.text
 
+    def test_request_hooks_accept_lists(self):
+        calls = []
+
+        def first_hook(data):
+            calls.append('first')
+            data['first'] = True
+            return data
+
+        def second_hook(data):
+            calls.append('second')
+            assert data['first'] is True
+            data['second'] = True
+            return data
+
+        request = requests.Request(
+            'http://example.com',
+            hooks={'args': [first_hook, second_hook]},
+        )
+
+        result = dispatch_hook('args', request.hooks, {})
+
+        self.assertEqual(calls, ['first', 'second'])
+        self.assertEqual(result, {'first': True, 'second': True})
+
     def test_session_persistent_cookies(self):
 
         s = requests.session()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/models\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_requests.py
cat coverage.cover
git checkout a0df2cbb10419037d11d04352b3175405ab52941
git apply /root/pre_state.patch
