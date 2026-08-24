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
    path('api/incidencias/<int:inc_id>/estado/', views.actualizar_estado, name='actualizar_estado'),   
    path('api/registro/', views.RegistroView.as_view(), name='registro'), 
    path('api/login/', views.LoginView.as_view(), name='login'), 

]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)