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
index 283353b..d665859 100755
--- a/test_requests.py
+++ b/test_requests.py
@@ -7,6 +7,7 @@ from __future__ import division
 import json
 import os
 import pickle
+import socket
 import unittest
 import collections
 
@@ -1421,5 +1422,21 @@ def test_prepared_request_complete_copy():
     )
     assert_copy(p, p.copy())
 
+
+def test_response_iter_content_socket_error():
+    """Socket errors while reading a response body are wrapped."""
+    class SocketErrorStream(object):
+        def stream(self, *args, **kwargs):
+            yield b'some data'
+            raise socket.error(104, 'Connection reset by peer')
+
+    response = requests.Response()
+    response.status_code = 200
+    response.raw = SocketErrorStream()
+
+    with pytest.raises(requests.exceptions.ConnectionError):
+        response.content
+
+
 if __name__ == '__main__':
     unittest.main()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/models\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_requests.py
cat coverage.cover
git checkout fe693c492242ae532211e0c173324f09ca8cf227
git apply /root/pre_state.patch
