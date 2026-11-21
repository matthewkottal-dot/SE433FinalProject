#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 091991be0da19de9108dbe5e3752917fea3d7fdc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 091991be0da19de9108dbe5e3752917fea3d7fdc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/requests/sessions.py b/requests/sessions.py
--- a/requests/sessions.py
+++ b/requests/sessions.py
@@ -13,7 +13,7 @@
 from datetime import datetime
 
 from .auth import _basic_auth_str
-from .compat import cookielib, OrderedDict, urljoin, urlparse, builtin_str
+from .compat import cookielib, OrderedDict, urljoin, urlparse
 from .cookies import (
     cookiejar_from_dict, extract_cookies_to_jar, RequestsCookieJar, merge_cookies)
 from .models import Request, PreparedRequest, DEFAULT_REDIRECT_LIMIT
@@ -425,7 +425,7 @@ def request(self, method, url,
             If Tuple, ('cert', 'key') pair.
         """
 
-        method = builtin_str(method)
+        method = to_native_string(method)
 
         # Create the Request.
         req = Request(

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/test_requests.py b/test_requests.py
index 467c5bc..73d94b8 100755
--- a/test_requests.py
+++ b/test_requests.py
@@ -523,6 +523,22 @@ class RequestsTestCase(unittest.TestCase):
             method=u('POST'), url=httpbin('post'), files=files)
         assert r.status_code == 200
 
+    def test_bytes_method_name(self):
+        session = requests.Session()
+        sent = []
+
+        def mock_send(request, **kwargs):
+            sent.append(request.method)
+            response = requests.Response()
+            response.status_code = 200
+            response.request = request
+            return response
+
+        session.send = mock_send
+        session.request(method=b'GET', url='http://example.com')
+
+        assert sent == ['GET']
+
     def test_custom_content_type(self):
         r = requests.post(
             httpbin('post'),

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/sessions\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_requests.py
cat coverage.cover
git checkout 091991be0da19de9108dbe5e3752917fea3d7fdc
git apply /root/pre_state.patch
