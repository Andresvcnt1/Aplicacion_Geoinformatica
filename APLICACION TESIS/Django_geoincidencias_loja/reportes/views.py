from rest_framework import generics
from .models import Incidencia
from .serializers import IncidenciaSerializer
from django.http import JsonResponse


class IncidenciasListCreateView(generics.ListCreateAPIView):
    """
    Controlador API que proporciona operaciones CRUD completas
    para los reportes de incidencias ciudadanas.
    """
    queryset = Incidencia.objects.all()
    serializer_class = IncidenciaSerializer


def incidencias_geojson(request):
    """
    Endpoint para servir datos en formato GeoJSON compatible con mapas interactivos.
    Cumple con RF006: Visualización de incidencias en mapa interactivo.
    """
    
    features = []
    for inc in Incidencia.objects.all():
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [inc.ubicacion.x, inc.ubicacion.y] 
            },
            "properties": {
                "id": inc.id,
                "categoria": inc.categoria,
                "descripcion": inc.descripcion,
                "foto_url": request.build_absolute_uri(inc.foto.url) if inc.foto else None,
                "fecha_reporte": inc.fecha_reporte.strftime('%Y-%m-%d %H:%M') if hasattr(inc, 'fecha_reporte') else None,
                "estado": inc.estado if hasattr(inc, 'estado') else None
            }
        })
    
    return JsonResponse({"type": "FeatureCollection", "features": features})