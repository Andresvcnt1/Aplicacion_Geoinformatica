from django.urls import path
from . import views

urlpatterns = [
    path('', views.IncidenciasListCreateView.as_view(), name='reportes-list-create'),
    path('incidencias-geojson/', views.incidencias_geojson, name='incidencias-geojson'), 
]