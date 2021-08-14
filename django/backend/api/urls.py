from django.urls import path, include
from .v1.routers import router as router_v1
urlpatterns = [
    path('v1/', include(router_v1.urls))
]