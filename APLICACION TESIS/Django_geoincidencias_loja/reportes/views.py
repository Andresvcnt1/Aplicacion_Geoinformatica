import json
from rest_framework import generics, parsers
from django.shortcuts import render                                      
from django.contrib.admin.views.decorators import staff_member_required 
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from django.views.decorators.csrf import ensure_csrf_cookie
from .models import Incidencia
from .serializers import IncidenciaSerializer

@ensure_csrf_cookie
@staff_member_required(login_url='/admin/login/')
def panel_administrativo(request):
    return render(request, 'panel_administrativo.html')

class IncidenciasListCreateView(generics.ListCreateAPIView):
    """
    Controlador API que proporciona operaciones CRUD completas
    para los reportes de incidencias ciudadanas.
    """
    queryset = Incidencia.objects.all().order_by('-fecha_creacion')
    serializer_class = IncidenciaSerializer
    parser_classes = (parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser)


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
                "fecha_reporte": inc.fecha_creacion.strftime('%Y-%m-%d %H:%M') if hasattr(inc, 'fecha_creacion') else None,
                "estado": inc.estado if hasattr(inc, 'estado') else None
            }
        })

    return JsonResponse({"type": "FeatureCollection", "features": features})

@staff_member_required(login_url='/admin/login/')
def panel_administrativo(request):
    """
    RF006: Panel web con mapa interactivo de incidencias.
    Solo accesible para personal técnico autenticado (superusuario/admin).
    """
    return render(request, 'panel_administrativo.html')

@staff_member_required(login_url='/admin/login/')
@require_POST
def actualizar_estado(request, inc_id):
    """RF008: Permite al personal técnico actualizar el estado de una incidencia."""
    try:
        payload = json.loads(request.body)
        nuevo_estado = payload.get('estado')
    except (json.JSONDecodeError, AttributeError):
        nuevo_estado = request.POST.get('estado')

    if not nuevo_estado:
        return JsonResponse({'error': 'Falta el campo estado'}, status=400)

    # Valida contra los choices reales de tu modelo (si existen)
    field = Incidencia._meta.get_field('estado')
    if field.choices:
        permitidos = [str(c[0]) for c in field.choices]
        if nuevo_estado not in permitidos:
            return JsonResponse({'error': 'Estado no válido', 'permitidos': permitidos}, status=400)

    try:
        incidencia = Incidencia.objects.get(id=inc_id)
    except Incidencia.DoesNotExist:
        return JsonResponse({'error': 'Incidencia no encontrada'}, status=404)

    incidencia.estado = nuevo_estado
    incidencia.save(update_fields=['estado'])
    return JsonResponse({'ok': True, 'id': incidencia.id, 'estado': incidencia})