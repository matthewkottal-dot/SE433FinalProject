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
diff --git a/requests/adapters.py b/requests/adapters.py
--- a/requests/adapters.py
+++ b/requests/adapters.py
@@ -19,6 +19,7 @@
 from .utils import (DEFAULT_CA_BUNDLE_PATH, get_encoding_from_headers,
                     prepend_scheme_if_needed, get_auth_from_url, urldefragauth)
 from .structures import CaseInsensitiveDict
+from .packages.urllib3.exceptions import ClosedPoolError
 from .packages.urllib3.exceptions import ConnectTimeoutError
 from .packages.urllib3.exceptions import HTTPError as _HTTPError
 from .packages.urllib3.exceptions import MaxRetryError
@@ -421,6 +422,9 @@ def send(self, request, stream=False, timeout=None, verify=True, cert=None, prox
 
             raise ConnectionError(e, request=request)
 
+        except ClosedPoolError as e:
+            raise ConnectionError(e, request=request)
+
         except _ProxyError as e:
             raise ProxyError(e)
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/test_requests.py b/test_requests.py
index 5f4f472..f4280c2 100755
--- a/test_requests.py
+++ b/test_requests.py
@@ -1655,6 +1655,26 @@ def test_urllib3_retries():
     with pytest.raises(RetryError):
         s.get(httpbin('status/500'))
 
+
+@pytest.mark.parametrize('exception', [
+    requests.packages.urllib3.exceptions.DecodeError('decode failed'),
+    requests.packages.urllib3.exceptions.TimeoutError('proxy timed out'),
+])
+def test_urllib3_exceptions_are_wrapped(exception):
+    """urllib3 exceptions should not escape from the Requests API."""
+    class FailingConnection(object):
+        def urlopen(self, *args, **kwargs):
+            raise exception
+
+    adapter = HTTPAdapter()
+    adapter.get_connection = lambda url, proxies=None: FailingConnection()
+    session = requests.Session()
+    session.mount('http://', adapter)
+
+    with pytest.raises(requests.exceptions.RequestException):
+        session.get('http://example.com/')
+
+
 def test_vendor_aliases():
     from requests.packages import urllib3
     from requests.packages import chardet

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/adapters\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_requests.py
cat coverage.cover
git checkout 0be38a0c37c59c4b66ce908731da15b401655113
git apply /root/pre_state.patch
