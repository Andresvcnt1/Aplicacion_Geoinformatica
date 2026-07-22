from rest_framework import generics
from .models import Incidencia
from .serializers import IncidenciaSerializer


class IncidenciasListCreateView(generics.ListCreateAPIView):
    """
    Controlador API que proporciona operaciones CRUD completas
    para los reportes de incidencias ciudadanas.
    """
    queryset = Incidencia.objects.all()
    serializer_class = IncidenciaSerializer