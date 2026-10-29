"""Api docs (drf-yasg) for the backend project.

Swagger UI:  /swagger/
ReDoc:       /redoc/
Openapi:     /swagger.json, /swagger.yaml
"""

import os

from django.urls import re_path
from drf_yasg import openapi
from drf_yasg.views import get_schema_view
from rest_framework import permissions

schema_view = get_schema_view(
    openapi.Info(
        title=os.environ.get('PROJECT_NAME', 'Backend') + ' API',
        default_version='v1',
        description="""<br><p>APP Name</p><br><br>SignIn to admin <a href="/admin/"> Admin page </a>""",
        terms_of_service="https://www.google.com/policies/terms/",
        contact=openapi.Contact(email="contact@snippets.local"),
        license=openapi.License(name="BSD License"),
    ),
    public=True,
    permission_classes=[permissions.AllowAny],
)

urlpatterns_docs = [
    re_path(r'^swagger(?P<format>\.json|\.yaml)$', schema_view.without_ui(cache_timeout=0), name='schema-json'),
    re_path(r'^swagger/$', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    re_path(r'^redoc/$', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
]
