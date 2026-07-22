from django.urls import path, include   
from .views import IncidenciasListCreateView

urlpatterns = [
    path('reportes/', IncidenciasListCreateView.as_view(), name='reportes-list-create'),
]