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
diff --git a/src/flask/blueprints.py b/src/flask/blueprints.py
--- a/src/flask/blueprints.py
+++ b/src/flask/blueprints.py
@@ -188,6 +188,10 @@ def __init__(
             template_folder=template_folder,
             root_path=root_path,
         )
+
+        if "." in name:
+            raise ValueError("'name' may not contain a dot '.' character.")
+
         self.name = name
         self.url_prefix = url_prefix
         self.subdomain = subdomain
@@ -360,12 +364,12 @@ def add_url_rule(
         """Like :meth:`Flask.add_url_rule` but for a blueprint.  The endpoint for
         the :func:`url_for` function is prefixed with the name of the blueprint.
         """
-        if endpoint:
-            assert "." not in endpoint, "Blueprint endpoints should not contain dots"
-        if view_func and hasattr(view_func, "__name__"):
-            assert (
-                "." not in view_func.__name__
-            ), "Blueprint view function name should not contain dots"
+        if endpoint and "." in endpoint:
+            raise ValueError("'endpoint' may not contain a dot '.' character.")
+
+        if view_func and hasattr(view_func, "__name__") and "." in view_func.__name__:
+            raise ValueError("'view_func' name may not contain a dot '.' character.")
+
         self.record(lambda s: s.add_url_rule(rule, endpoint, view_func, **options))
 
     def app_template_filter(self, name: t.Optional[str] = None) -> t.Callable:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_basic.py b/tests/test_basic.py
index d6ec3fe4..7c8cbf2b 100755
--- a/tests/test_basic.py
+++ b/tests/test_basic.py
@@ -1631,7 +1631,7 @@ def test_url_processors(app, client):
 
 
 def test_inject_blueprint_url_defaults(app):
-    bp = flask.Blueprint("foo.bar.baz", __name__, template_folder="template")
+    bp = flask.Blueprint("bp", __name__, template_folder="template")
 
     @bp.url_defaults
     def bp_defaults(endpoint, values):
@@ -1644,12 +1644,12 @@ def test_inject_blueprint_url_defaults(app):
     app.register_blueprint(bp)
 
     values = dict()
-    app.inject_url_defaults("foo.bar.baz.view", values)
+    app.inject_url_defaults("bp.view", values)
     expected = dict(page="login")
     assert values == expected
 
     with app.test_request_context("/somepage"):
-        url = flask.url_for("foo.bar.baz.view")
+        url = flask.url_for("bp.view")
     expected = "/login"
     assert url == expected
 
diff --git a/tests/test_blueprints.py b/tests/test_blueprints.py
index b986ca02..4e303936 100755
--- a/tests/test_blueprints.py
+++ b/tests/test_blueprints.py
@@ -253,9 +253,16 @@ def test_templates_list(test_apps):
     assert templates == ["admin/index.html", "frontend/index.html"]
 
 
+@pytest.mark.parametrize("name", ["bp.name", ".bp", "bp.", "."])
+def test_blueprint_name_with_dot(name):
+    with pytest.raises(ValueError):
+        flask.Blueprint(name, __name__)
+
+
 def test_dotted_names(app, client):
-    frontend = flask.Blueprint("myapp.frontend", __name__)
-    backend = flask.Blueprint("myapp.backend", __name__)
+    myapp = flask.Blueprint("myapp", __name__)
+    frontend = flask.Blueprint("frontend", __name__)
+    backend = flask.Blueprint("backend", __name__)
 
     @frontend.route("/fe")
     def frontend_index():
@@ -269,8 +276,9 @@ def test_dotted_names(app, client):
     def backend_index():
         return flask.url_for("myapp.frontend.frontend_index")
 
-    app.register_blueprint(frontend)
-    app.register_blueprint(backend)
+    myapp.register_blueprint(frontend)
+    myapp.register_blueprint(backend)
+    app.register_blueprint(myapp)
 
     assert client.get("/fe").data.strip() == b"/be"
     assert client.get("/fe2").data.strip() == b"/fe"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/flask/blueprints\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_basic.py tests/test_blueprints.py
cat coverage.cover
git checkout d8c37f43724cd9fb0870f77877b7c4c7e38a19e0
git apply /root/pre_state.patch
