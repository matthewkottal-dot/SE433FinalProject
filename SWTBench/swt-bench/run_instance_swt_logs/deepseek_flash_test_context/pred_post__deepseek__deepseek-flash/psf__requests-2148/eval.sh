#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fe693c492242ae532211e0c173324f09ca8cf227 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fe693c492242ae532211e0c173324f09ca8cf227
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/requests/models.py b/requests/models.py
--- a/requests/models.py
+++ b/requests/models.py
@@ -9,6 +9,7 @@
 
 import collections
 import datetime
+import socket
 
 from io import BytesIO, UnsupportedOperation
 from .hooks import default_hooks
@@ -22,7 +23,7 @@
 from .packages.urllib3.exceptions import DecodeError
 from .exceptions import (
     HTTPError, RequestException, MissingSchema, InvalidURL,
-    ChunkedEncodingError, ContentDecodingError)
+    ChunkedEncodingError, ContentDecodingError, ConnectionError)
 from .utils import (
     guess_filename, get_auth_from_url, requote_uri,
     stream_decode_response_unicode, to_key_val_list, parse_header_links,
@@ -640,6 +641,8 @@ def generate():
                     raise ChunkedEncodingError(e)
                 except DecodeError as e:
                     raise ContentDecodingError(e)
+                except socket.error as e:
+                    raise ConnectionError(e)
             except AttributeError:
                 # Standard file-like object.
                 while True:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/test_requests.py b/test_requests.py
index 283353b..480a8b0 100755
--- a/test_requests.py
+++ b/test_requests.py
@@ -7,6 +7,7 @@ from __future__ import division
 import json
 import os
 import pickle
+import socket
 import unittest
 import collections
 
@@ -18,7 +19,7 @@ from requests.auth import HTTPDigestAuth, _basic_auth_str
 from requests.compat import (
     Morsel, cookielib, getproxies, str, urljoin, urlparse, is_py3, builtin_str)
 from requests.cookies import cookiejar_from_dict, morsel_to_cookie
-from requests.exceptions import InvalidURL, MissingSchema
+from requests.exceptions import ConnectionError, InvalidURL, MissingSchema
 from requests.models import PreparedRequest
 from requests.structures import CaseInsensitiveDict
 from requests.sessions import SessionRedirectMixin
@@ -720,6 +721,18 @@ class RequestsTestCase(unittest.TestCase):
         assert next(iter(r))
         io.close()
 
+    def test_response_connection_error(self):
+        """A socket error while reading the body is wrapped as ConnectionError."""
+        class Raw(object):
+            def stream(self, *args, **kwargs):
+                raise socket.error(104, 'Connection reset by peer')
+
+        r = requests.Response()
+        r.raw = Raw()
+
+        with pytest.raises(ConnectionError):
+            r.content
+
     def test_response_decode_unicode(self):
         """
         When called with decode_unicode, Response.iter_content should always

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/models\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_requests.py
cat coverage.cover
git checkout fe693c492242ae532211e0c173324f09ca8cf227
git apply /root/pre_state.patch
