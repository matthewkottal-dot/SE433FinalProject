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
diff --git a/tests/user_commands/tests.py b/tests/user_commands/tests.py
index 9262e2717a..ffe7498d29 100755
--- a/tests/user_commands/tests.py
+++ b/tests/user_commands/tests.py
@@ -54,6 +54,13 @@ class CommandTests(SimpleTestCase):
         with self.assertRaisesMessage(CommandError, "Unknown command: 'explode'"):
             management.call_command(('explode',))
 
+    @mock.patch('sys.argv', [None])
+    def test_management_utility_uses_custom_argv_prog_name(self):
+        out = StringIO()
+        with mock.patch('sys.stdout', out):
+            management.execute_from_command_line(['custom_prog', 'help'])
+        self.assertIn("Type 'custom_prog help <subcommand>'", out.getvalue())
+
     def test_system_exit(self):
         """ Exception raised in a command should raise CommandError with
             call_command, but SystemExit when run from command line

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 user_commands.tests
cat coverage.cover
git checkout 0773837e15bb632afffb6848a58c59a791008fa1
git apply /root/pre_state.patch
