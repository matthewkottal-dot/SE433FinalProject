#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 110048f9837f8441ea536804115e80b69f400277 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 110048f9837f8441ea536804115e80b69f400277
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/requests/sessions.py b/requests/sessions.py
--- a/requests/sessions.py
+++ b/requests/sessions.py
@@ -168,8 +168,11 @@ def resolve_redirects(self, resp, req, stream=False, timeout=None,
             if new_auth is not None:
                 prepared_request.prepare_auth(new_auth)
 
+            # Override the original request.
+            req = prepared_request
+
             resp = self.send(
-                prepared_request,
+                req,
                 stream=stream,
                 timeout=timeout,
                 verify=verify,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/test_requests.py b/test_requests.py
index 17de849..7a07236 100755
--- a/test_requests.py
+++ b/test_requests.py
@@ -118,6 +118,50 @@ class RequestsTestCase(unittest.TestCase):
         assert r.history[0].status_code == 302
         assert r.history[0].is_redirect
 
+    def test_redirect_preserves_method_from_previous_request(self):
+        """Ensure redirects do not replay the original request's method."""
+
+        class Raw(object):
+            def stream(self, *args, **kwargs):
+                return iter(())
+
+            def read(self, *args, **kwargs):
+                return b''
+
+            def release_conn(self):
+                pass
+
+        class RedirectAdapter(object):
+            def __init__(self):
+                self.requests = []
+                self.responses = [
+                    (303, {'location': '/new_thing_1513'}),
+                    (307, {'location': '//failover.example.com/new_thing_1513'}),
+                    (200, {}),
+                ]
+
+            def send(self, request, **kwargs):
+                self.requests.append(request)
+                status_code, headers = self.responses.pop(0)
+                response = requests.Response()
+                response.status_code = status_code
+                response.headers = CaseInsensitiveDict(headers)
+                response.url = request.url
+                response.request = request
+                response.raw = Raw()
+                return response
+
+        session = requests.Session()
+        adapter = RedirectAdapter()
+        session.mount('http://', adapter)
+
+        response = session.post(
+            'http://server.example.com/do_something', data={'foo': 'bar'})
+
+        assert [request.method for request in adapter.requests] == [
+            'POST', 'GET', 'GET']
+        assert response.request.method == 'GET'
+
     # def test_HTTP_302_ALLOW_REDIRECT_POST(self):
     #     r = requests.post(httpbin('status', '302'), data={'some': 'data'})
     #     self.assertEqual(r.status_code, 200)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/sessions\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_requests.py
cat coverage.cover
git checkout 110048f9837f8441ea536804115e80b69f400277
git apply /root/pre_state.patch
