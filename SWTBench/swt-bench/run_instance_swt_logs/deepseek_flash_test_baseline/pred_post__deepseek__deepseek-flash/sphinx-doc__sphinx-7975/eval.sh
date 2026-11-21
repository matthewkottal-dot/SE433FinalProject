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
diff --git a/sphinx/environment/adapters/indexentries.py b/sphinx/environment/adapters/indexentries.py
--- a/sphinx/environment/adapters/indexentries.py
+++ b/sphinx/environment/adapters/indexentries.py
@@ -98,9 +98,8 @@ def keyfunc0(entry: Tuple[str, str]) -> Tuple[bool, str]:
             for subentry in indexentry[1].values():
                 subentry[0].sort(key=keyfunc0)  # type: ignore
 
-        # sort the index entries; put all symbols at the front, even those
-        # following the letters in ASCII, this is where the chr(127) comes from
-        def keyfunc(entry: Tuple[str, List]) -> Tuple[str, str]:
+        # sort the index entries
+        def keyfunc(entry: Tuple[str, List]) -> Tuple[Tuple[int, str], str]:
             key, (void, void, category_key) = entry
             if category_key:
                 # using specified category key to sort
@@ -108,11 +107,16 @@ def keyfunc(entry: Tuple[str, List]) -> Tuple[str, str]:
             lckey = unicodedata.normalize('NFD', key.lower())
             if lckey.startswith('\N{RIGHT-TO-LEFT MARK}'):
                 lckey = lckey[1:]
+
             if lckey[0:1].isalpha() or lckey.startswith('_'):
-                lckey = chr(127) + lckey
+                # put non-symbol characters at the folloing group (1)
+                sortkey = (1, lckey)
+            else:
+                # put symbols at the front of the index (0)
+                sortkey = (0, lckey)
             # ensure a determinstic order *within* letters by also sorting on
             # the entry itself
-            return (lckey, entry[0])
+            return (sortkey, entry[0])
         newlist = sorted(new.items(), key=keyfunc)
 
         if group_entries:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_environment_indexentries.py b/tests/test_environment_indexentries.py
index 7f6003d54..6e8674b02 100755
--- a/tests/test_environment_indexentries.py
+++ b/tests/test_environment_indexentries.py
@@ -163,3 +163,18 @@ def test_create_index_by_key(app):
     assert index[0] == ('D', [('docutils', [[('main', '#term-docutils')], [], None])])
     assert index[1] == ('P', [('Python', [[('main', '#term-Python')], [], None])])
     assert index[2] == ('ス', [('スフィンクス', [[('main', '#term-0')], [], 'ス'])])
+
+
+@pytest.mark.sphinx('dummy', freshenv=True)
+def test_create_single_index_with_symbols(app):
+    text = (".. index:: @-symbol\n"
+            ".. index:: docutils\n"
+            ".. index:: £-symbol\n"
+            ".. index:: ←-symbol\n")
+    restructuredtext.parse(app, text)
+    index = IndexEntries(app.env).create_index(app.builder)
+
+    assert [key for key, entries in index] == ['Symbols', 'D']
+    symbols = [entries for (key, entries) in index if key == 'Symbols']
+    assert len(symbols) == 1
+    assert {entry[0] for entry in index[0][1]} == {'@-symbol', '£-symbol', '←-symbol'}

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/environment/adapters/indexentries\.py)' -m tox -epy39 -v -- tests/test_environment_indexentries.py
cat coverage.cover
git checkout 4ec6cbe341fd84468c448e20082c778043bbea4b
git apply /root/pre_state.patch
