#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4ec6cbe341fd84468c448e20082c778043bbea4b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4ec6cbe341fd84468c448e20082c778043bbea4b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_environment_indexentries.py b/tests/test_environment_indexentries.py
index 7f6003d54..3c10a19cf 100755
--- a/tests/test_environment_indexentries.py
+++ b/tests/test_environment_indexentries.py
@@ -163,3 +163,21 @@ def test_create_index_by_key(app):
     assert index[0] == ('D', [('docutils', [[('main', '#term-docutils')], [], None])])
     assert index[1] == ('P', [('Python', [[('main', '#term-Python')], [], None])])
     assert index[2] == ('ス', [('スフィンクス', [[('main', '#term-0')], [], 'ス'])])
+
+
+@pytest.mark.sphinx('dummy', freshenv=True)
+def test_create_index_with_non_ascii_symbols(app):
+    text = (".. index:: @\n"
+            ".. index:: docutils\n"
+            ".. index:: £\n"
+            ".. index:: ←\n")
+    restructuredtext.parse(app, text)
+    index = IndexEntries(app.env).create_index(app.builder)
+
+    # All symbols should be grouped into a single section, even when some
+    # sort after the ASCII letters used to place alphabetical entries first.
+    assert len(index) == 2
+    assert index[0] == ('Symbols', [('@', [[('', '#index-0')], [], None]),
+                                    ('£', [[('', '#index-2')], [], None]),
+                                    ('←', [[('', '#index-3')], [], None])])
+    assert index[1] == ('D', [('docutils', [[('', '#index-1')], [], None])])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/environment/adapters/indexentries\.py)' -m tox -epy39 -v -- tests/test_environment_indexentries.py
cat coverage.cover
git checkout 4ec6cbe341fd84468c448e20082c778043bbea4b
git apply /root/pre_state.patch
