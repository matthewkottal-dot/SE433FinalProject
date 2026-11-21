#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0773837e15bb632afffb6848a58c59a791008fa1 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0773837e15bb632afffb6848a58c59a791008fa1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_scripts/tests.py b/tests/admin_scripts/tests.py
index 62c6f485aa..1ea8a68e3e 100755
--- a/tests/admin_scripts/tests.py
+++ b/tests/admin_scripts/tests.py
@@ -17,7 +17,7 @@ from unittest import mock
 from django import conf, get_version
 from django.conf import settings
 from django.core.management import (
-    BaseCommand, CommandError, call_command, color,
+    BaseCommand, CommandError, call_command, color, execute_from_command_line,
 )
 from django.core.management.commands.loaddata import Command as LoaddataCommand
 from django.core.management.commands.runserver import (
@@ -162,6 +162,16 @@ class AdminScriptTestCase(SimpleTestCase):
         "Utility assertion: assert that the given message doesn't exist in the output"
         self.assertNotIn(msg, stream, "'%s' matches actual output text '%s'" % (msg, stream))
 
+
+class ManagementUtilityTests(SimpleTestCase):
+    def test_program_name_from_argv(self):
+        argv = ['django-admin', 'version']
+        with mock.patch('sys.argv', [None]):
+            with mock.patch('sys.stdout', new_callable=StringIO) as stdout:
+                execute_from_command_line(argv)
+        self.assertEqual(stdout.getvalue(), get_version() + '\n')
+
+
 ##########################################################################
 # DJANGO ADMIN TESTS
 # This first series of test classes checks the environment processing

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_scripts.tests
cat coverage.cover
git checkout 0773837e15bb632afffb6848a58c59a791008fa1
git apply /root/pre_state.patch
