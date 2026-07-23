from django.http import JsonResponse
from django.urls import path
from django.db import connections
from django.core.cache import cache


def healthz(request):
    status = {"status": "healthy", "service": "django"}
    
    # Check PostgreSQL
    try:
        with connections['default'].cursor() as cursor:
            cursor.execute("SELECT 1")
        status["postgresql"] = "connected"
    except Exception as e:
        status["postgresql"] = f"disconnected: {str(e)}"
        status["status"] = "degraded"
    
    # Check Redis (Django cache backend)
    try:
        cache.get("_health_check_")
        status["redis"] = "connected"
    except Exception:
        status["redis"] = "disconnected"
        status["status"] = "degraded"
    
    code = 503 if status["status"] != "healthy" else 200
    return JsonResponse(status, status=code)


urlpatterns_health = [
    path("healthz/", healthz, name="healthz"),
]
