#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 88b81a06eb635a1596617f8971fa97a84c069e93 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 88b81a06eb635a1596617f8971fa97a84c069e93
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/builders/manpage.py b/sphinx/builders/manpage.py
--- a/sphinx/builders/manpage.py
+++ b/sphinx/builders/manpage.py
@@ -24,7 +24,7 @@
 from sphinx.util import progress_message
 from sphinx.util.console import darkgreen  # type: ignore
 from sphinx.util.nodes import inline_all_toctrees
-from sphinx.util.osutil import make_filename_from_project
+from sphinx.util.osutil import ensuredir, make_filename_from_project
 from sphinx.writers.manpage import ManualPageWriter, ManualPageTranslator
 
 
@@ -80,7 +80,12 @@ def write(self, *ignored: Any) -> None:
             docsettings.authors = authors
             docsettings.section = section
 
-            targetname = '%s.%s' % (name, section)
+            if self.config.man_make_section_directory:
+                ensuredir(path.join(self.outdir, str(section)))
+                targetname = '%s/%s.%s' % (section, name, section)
+            else:
+                targetname = '%s.%s' % (name, section)
+
             logger.info(darkgreen(targetname) + ' { ', nonl=True)
             destination = FileOutput(
                 destination_path=path.join(self.outdir, targetname),
@@ -115,6 +120,7 @@ def setup(app: Sphinx) -> Dict[str, Any]:
 
     app.add_config_value('man_pages', default_man_pages, None)
     app.add_config_value('man_show_urls', False, None)
+    app.add_config_value('man_make_section_directory', False, None)
 
     return {
         'version': 'builtin',

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_build_manpage.py b/tests/test_build_manpage.py
index c3c41a2ae..4b622463e 100755
--- a/tests/test_build_manpage.py
+++ b/tests/test_build_manpage.py
@@ -17,9 +17,9 @@ from sphinx.config import Config
 @pytest.mark.sphinx('man')
 def test_all(app, status, warning):
     app.builder.build_all()
-    assert (app.outdir / 'sphinxtests.1').exists()
+    assert (app.outdir / 'man1' / 'sphinxtests.1').exists()
 
-    content = (app.outdir / 'sphinxtests.1').read_text()
+    content = (app.outdir / 'man1' / 'sphinxtests.1').read_text()
     assert r'\fBprint \fP\fIi\fP\fB\en\fP' in content
     assert r'\fBmanpage\en\fP' in content
 
@@ -33,7 +33,7 @@ def test_all(app, status, warning):
 @pytest.mark.sphinx('man', testroot='directive-code')
 def test_captioned_code_block(app, status, warning):
     app.builder.build_all()
-    content = (app.outdir / 'python.1').read_text()
+    content = (app.outdir / 'man1' / 'python.1').read_text()
 
     assert ('.sp\n'
             'caption \\fItest\\fP rb\n'
@@ -64,5 +64,23 @@ def test_default_man_pages():
 @pytest.mark.sphinx('man', testroot='markup-rubric')
 def test_rubric(app, status, warning):
     app.build()
-    content = (app.outdir / 'python.1').read_text()
+    content = (app.outdir / 'man1' / 'python.1').read_text()
     assert 'This is a rubric\n' in content
+
+
+@pytest.mark.sphinx('man', confoverrides={
+    'man_pages': [
+        ('index', 'sphinxtests', 'Sphinx Tests', ['Sphinx Team'], 1),
+        ('markup', 'sphinxtests-markup', 'Sphinx Tests', ['Sphinx Team'], 3),
+    ],
+})
+def test_man_pages_in_section_directories(app, status, warning):
+    app.build()
+
+    assert (app.outdir / 'man1' / 'sphinxtests.1').exists()
+    assert (app.outdir / 'man3' / 'sphinxtests-markup.3').exists()
+
+    # Man pages must not remain in the top-level output directory, since man(1)
+    # does not search that directory when MANPATH is set to the build output.
+    assert not (app.outdir / 'sphinxtests.1').exists()
+    assert not (app.outdir / 'sphinxtests-markup.3').exists()
diff --git a/tests/test_smartquotes.py b/tests/test_smartquotes.py
index 6276e6a74..f3a889468 100755
--- a/tests/test_smartquotes.py
+++ b/tests/test_smartquotes.py
@@ -33,7 +33,7 @@ def test_text_builder(app, status, warning):
 def test_man_builder(app, status, warning):
     app.build()
 
-    content = (app.outdir / 'python.1').read_text()
+    content = (app.outdir / 'man1' / 'python.1').read_text()
     assert '\\-\\- "Sphinx" is a tool that makes it easy ...' in content
 
 
@@ -88,5 +88,5 @@ def test_smartquotes_excludes_language(app, status, warning):
 def test_smartquotes_excludes_builders(app, status, warning):
     app.build()
 
-    content = (app.outdir / 'python.1').read_text()
+    content = (app.outdir / 'man1' / 'python.1').read_text()
     assert '– “Sphinx” is a tool that makes it easy …' in content

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/builders/manpage\.py)' -m tox -epy39 -v -- tests/test_build_manpage.py tests/test_smartquotes.py
cat coverage.cover
git checkout 88b81a06eb635a1596617f8971fa97a84c069e93
git apply /root/pre_state.patch
