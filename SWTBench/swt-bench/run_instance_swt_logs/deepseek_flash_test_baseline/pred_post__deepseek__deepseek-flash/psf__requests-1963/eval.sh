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
index 17de849..aa4f773 100755
--- a/test_requests.py
+++ b/test_requests.py
@@ -122,6 +122,54 @@ class RequestsTestCase(unittest.TestCase):
     #     r = requests.post(httpbin('status', '302'), data={'some': 'data'})
     #     self.assertEqual(r.status_code, 200)
 
+    def test_redirect_after_303_preserves_get_method(self):
+        class FakeRaw(object):
+            _original_response = None
+
+            def read(self, *args, **kwargs):
+                return b''
+
+            def stream(self, *args, **kwargs):
+                return iter(())
+
+            def release_conn(self):
+                pass
+
+        class FakeAdapter(HTTPAdapter):
+            def __init__(self, responses):
+                self.responses = list(responses)
+                self.requests = []
+
+            def send(self, request, **kwargs):
+                self.requests.append(request)
+                response = self.responses.pop(0)
+                response.request = request
+                response.url = request.url
+                return response
+
+        def response(status_code, location=None):
+            response = requests.Response()
+            response.status_code = status_code
+            response.raw = FakeRaw()
+            if location is not None:
+                response.headers['location'] = location
+            return response
+
+        adapter = FakeAdapter([
+            response(303, '/new_thing_1513'),
+            response(307, '//failover.example.com/new_thing_1513'),
+            response(200),
+        ])
+        session = requests.Session()
+        session.mount('http://', adapter)
+
+        response = session.post('http://server.example.com/do_something')
+
+        assert [request.method for request in adapter.requests] == [
+            'POST', 'GET', 'GET']
+        assert response.request.method == 'GET'
+        assert [r.request.method for r in response.history] == ['POST', 'GET']
+
     def test_HTTP_200_OK_GET_WITH_PARAMS(self):
         heads = {'User-agent': 'Mozilla/5.0'}
 

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/sessions\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_requests.py
cat coverage.cover
git checkout 110048f9837f8441ea536804115e80b69f400277
git apply /root/pre_state.patch
