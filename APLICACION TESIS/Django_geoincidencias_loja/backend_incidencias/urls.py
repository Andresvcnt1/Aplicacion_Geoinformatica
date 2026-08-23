from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from reportes import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/reportes/', include('reportes.urls')),
    path('api/incidencias-geojson/', views.incidencias_geojson, name='incidencias-geojson'),
    path('panel/', views.panel_administrativo, name='panel_administrativo'),  
    
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)