from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import TokenRefreshView
from reportes import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/reportes/', include('reportes.urls')),
    path('api/incidencias-geojson/', views.incidencias_geojson, name='incidencias-geojson'),
    path('panel/', views.panel_administrativo, name='panel_administrativo'),

    # Ciclo de vida y trazabilidad
    path('api/incidencias/<int:inc_id>/estado/', views.ActualizarEstadoView.as_view(), name='actualizar_estado'),
    path('api/incidencias/<int:inc_id>/historial/', views.HistorialIncidenciaView.as_view(), name='historial_incidencia'),
    path('api/informe-mensual/', views.InformeMensualPDFView.as_view(), name='informe_mensual'),

    # Modelo freemium
    path('api/suscripcion/', views.SuscripcionView.as_view(), name='suscripcion'),
    path('api/anuncios/', views.AnunciosView.as_view(), name='anuncios'),

    path('api/registro/', views.RegistroView.as_view(), name='registro'),
    path('api/login/', views.LoginView.as_view(), name='login'),
    path('api/admin/access/', views.AdminAccessView.as_view(), name='admin-access'),
    path('api/perfil/', views.PerfilView.as_view(), name='perfil'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/admin-login/', views.AdminLoginView.as_view(), name='admin_login'),
    path('api/geocercas-geojson/', views.geocercas_geojson, name='geocercas-geojson'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)