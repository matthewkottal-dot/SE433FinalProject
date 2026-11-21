#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d8c37f43724cd9fb0870f77877b7c4c7e38a19e0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d8c37f43724cd9fb0870f77877b7c4c7e38a19e0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_blueprints.py b/tests/test_blueprints.py
index b986ca02..22961429 100755
--- a/tests/test_blueprints.py
+++ b/tests/test_blueprints.py
@@ -253,28 +253,15 @@ def test_templates_list(test_apps):
     assert templates == ["admin/index.html", "frontend/index.html"]
 
 
-def test_dotted_names(app, client):
-    frontend = flask.Blueprint("myapp.frontend", __name__)
-    backend = flask.Blueprint("myapp.backend", __name__)
+def test_dotted_names():
+    with pytest.raises(ValueError, match="may not contain a dot"):
+        flask.Blueprint("myapp.frontend", __name__)
 
-    @frontend.route("/fe")
-    def frontend_index():
-        return flask.url_for("myapp.backend.backend_index")
 
-    @frontend.route("/fe2")
-    def frontend_page2():
-        return flask.url_for(".frontend_index")
-
-    @backend.route("/be")
-    def backend_index():
-        return flask.url_for("myapp.frontend.frontend_index")
-
-    app.register_blueprint(frontend)
-    app.register_blueprint(backend)
-
-    assert client.get("/fe").data.strip() == b"/be"
-    assert client.get("/fe2").data.strip() == b"/fe"
-    assert client.get("/be").data.strip() == b"/fe"
+@pytest.mark.parametrize("name", [".frontend", "frontend.", "my.app.frontend"])
+def test_blueprint_name_with_dot(name):
+    with pytest.raises(ValueError, match="may not contain a dot"):
+        flask.Blueprint(name, __name__)
 
 
 def test_dotted_names_from_app(app, client):

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/flask/blueprints\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_blueprints.py
cat coverage.cover
git checkout d8c37f43724cd9fb0870f77877b7c4c7e38a19e0
git apply /root/pre_state.patch
