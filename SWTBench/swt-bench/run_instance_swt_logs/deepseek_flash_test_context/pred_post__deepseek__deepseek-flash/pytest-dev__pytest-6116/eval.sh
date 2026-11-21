#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e670ff76cbad80108bde9bab616b66771b8653cf >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e670ff76cbad80108bde9bab616b66771b8653cf
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/src/_pytest/main.py b/src/_pytest/main.py
--- a/src/_pytest/main.py
+++ b/src/_pytest/main.py
@@ -109,6 +109,7 @@ def pytest_addoption(parser):
     group.addoption(
         "--collectonly",
         "--collect-only",
+        "--co",
         action="store_true",
         help="only collect tests, don't execute them.",
     ),

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_collection.py b/testing/test_collection.py
index 259868357..99dc59ac1 100755
--- a/testing/test_collection.py
+++ b/testing/test_collection.py
@@ -1257,3 +1257,16 @@ def test_collector_respects_tbstyle(testdir):
             "*= 1 error in *",
         ]
     )
+
+
+def test_collect_only_with_short_option(testdir):
+    """``--co`` is a shortcut for ``--collect-only``."""
+    testdir.makepyfile(
+        """
+        def test_collected():
+            assert False
+        """
+    )
+    result = testdir.runpytest("--co")
+    assert result.ret == ExitCode.OK
+    result.stdout.fnmatch_lines(["*test_collected*", "collected 1 item*"])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/main\.py)' -m pytest -rA testing/test_collection.py
cat coverage.cover
git checkout e670ff76cbad80108bde9bab616b66771b8653cf
git apply /root/pre_state.patch
