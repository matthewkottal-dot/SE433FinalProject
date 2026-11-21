#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0be38a0c37c59c4b66ce908731da15b401655113 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0be38a0c37c59c4b66ce908731da15b401655113
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/test_requests.py b/test_requests.py
index 5f4f472..0eb9c29 100755
--- a/test_requests.py
+++ b/test_requests.py
@@ -1518,6 +1518,36 @@ class TestTimeout:
         assert r.ok
 
 
+class TestUrllib3ExceptionWrapping(object):
+    """urllib3 exceptions should not leak through Requests' public API."""
+
+    def _get_with_error(self, error):
+        class ErrorConnection(object):
+            def urlopen(self, *args, **kwargs):
+                raise error
+
+        class ErrorAdapter(HTTPAdapter):
+            def get_connection(self, *args, **kwargs):
+                return ErrorConnection()
+
+        session = requests.Session()
+        session.trust_env = False
+        session.mount('http://', ErrorAdapter())
+        return session.get('http://example.com/')
+
+    def test_decode_error_is_wrapped(self):
+        from requests.packages.urllib3.exceptions import DecodeError
+
+        with pytest.raises(requests.exceptions.RequestException):
+            self._get_with_error(DecodeError('bad response body'))
+
+    def test_timeout_error_is_wrapped(self):
+        from requests.packages.urllib3.exceptions import TimeoutError
+
+        with pytest.raises(requests.exceptions.RequestException):
+            self._get_with_error(TimeoutError('proxy timed out'))
+
+
 SendCall = collections.namedtuple('SendCall', ('args', 'kwargs'))
 
 

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/adapters\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_requests.py
cat coverage.cover
git checkout 0be38a0c37c59c4b66ce908731da15b401655113
git apply /root/pre_state.patch
