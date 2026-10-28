import json

from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth import authenticate
from django.core.exceptions import ValidationError
from django.http import FileResponse, JsonResponse
from django.shortcuts import render
from django.utils import timezone
from django.views.decorators.csrf import ensure_csrf_cookie
from rest_framework import generics, parsers, status
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .informe_mensual import generar_informe_mensual
from .models import (
    Anuncio,
    DispositivoPush,
    GeocercaMunicipal,
    HistorialEstado,
    Incidencia,
    Usuario,
)
from .serializers import (
    AnuncioSerializer,
    DispositivoPushBajaSerializer,
    DispositivoPushRegistroSerializer,
    HistorialEstadoSerializer,
    IncidenciaSerializer,
    PerfilSerializer,
    RegistroUsuarioSerializer,
)


class DispositivoPushView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DispositivoPushRegistroSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        dispositivo = serializer.save()
        creado = serializer.created
        return Response(
            {
                'mensaje': 'Dispositivo registrado correctamente.',
                'id': dispositivo.pk,
                'plataforma': dispositivo.plataforma,
            },
            status=status.HTTP_201_CREATED if creado else status.HTTP_200_OK,
        )

    def delete(self, request):
        serializer = DispositivoPushBajaSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        actualizado = DispositivoPush.objects.filter(
            usuario=request.user,
            token=serializer.validated_data['token'],
        ).update(
            activo=False,
            fecha_actualizacion=timezone.now(),
        )
        if not actualizado:
            return Response(
                {'error': 'Dispositivo no encontrado.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(
            {'mensaje': 'Dispositivo dado de baja correctamente.'},
            status=status.HTTP_200_OK,
        )


@ensure_csrf_cookie
@staff_member_required(login_url='/admin/login/')
def panel_administrativo(request):
    """
    RF006: Panel web con mapa interactivo de incidencias.
    Solo accesible para personal técnico autenticado (superusuario/admin).
    """
    return render(request, 'panel_administrativo.html')


class IncidenciasListCreateView(generics.ListCreateAPIView):
    """
    Controlador API para los reportes de incidencias ciudadanas.
    Lectura pública (feed de publicaciones), creación requiere login.
    - ?mios=1 devuelve solo los reportes del usuario autenticado.
    El primer registro del historial lo crea Incidencia.save().
    """
    serializer_class = IncidenciaSerializer
    parser_classes = (parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser)

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsAuthenticated()]
        return [AllowAny()]

    def get_queryset(self):
        qs = Incidencia.objects.select_related('usuario')
        user = self.request.user
        solo_mios = self.request.query_params.get('mios') == '1'

        if solo_mios:
            if not user.is_authenticated:
                return qs.none()
            return qs.filter(usuario=user).order_by('-fecha_creacion')

        return qs.order_by('-fecha_creacion')

    def perform_create(self, serializer):
        user = self.request.user
        anonimo = bool(serializer.validated_data.get('anonimo', False))
        serializer.save(usuario=user, anonimo=anonimo)


def geocercas_geojson(request):
    """
    Endpoint de apoyo/referencia: expone las geocercas municipales en GeoJSON
    para visualización mientras se trazan límites (temporal, solo lectura).
    """
    features = []
    for geo in GeocercaMunicipal.objects.all():
        features.append({
            "type": "Feature",
            "geometry": json.loads(geo.area.geojson),
            "properties": {
                "id": geo.id,
                "nombre": geo.nombre,
                "activa": geo.activa,
            }
        })
    return JsonResponse({"type": "FeatureCollection", "features": features})


def incidencias_geojson(request):
    """
    Endpoint GeoJSON para mapas interactivos.
    Cumple con RF006: Visualización de incidencias en mapa interactivo.
    fecha_reporte: texto para el panel web; fecha_iso: fecha con zona horaria para la app.
    """
    features = []
    for inc in Incidencia.objects.all():
        local = timezone.localtime(inc.fecha_creacion)
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
                "fecha_reporte": local.strftime('%Y-%m-%d %H:%M'),
                "fecha_iso": local.isoformat(),
                "estado": inc.estado if hasattr(inc, 'estado') else None
            }
        })

    return JsonResponse({"type": "FeatureCollection", "features": features})


class ActualizarEstadoView(APIView):
    """Permite al personal técnico cambiar el estado de una incidencia.
    Body: {"estado": "en_proceso", "observacion": "texto opcional"}
    Mantiene el formato de respuesta anterior (ok / id / estado) para no romper el panel."""
    permission_classes = [IsAdminUser]

    def post(self, request, inc_id):
        nuevo_estado = request.data.get('estado')
        observacion = request.data.get('observacion', '')

        if not nuevo_estado:
            return Response({'error': 'Falta el campo estado'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            incidencia = Incidencia.objects.get(id=inc_id)
        except Incidencia.DoesNotExist:
            return Response({'error': 'Incidencia no encontrada'}, status=status.HTTP_404_NOT_FOUND)

        try:
            registro = incidencia.cambiar_estado(nuevo_estado, request.user, observacion)
        except ValidationError as e:
            return Response(
                {
                    'error': e.messages[0],
                    'permitidos': [
                        {'valor': v, 'etiqueta': dict(Incidencia.Estado.choices)[v]}
                        for v in sorted(Incidencia.TRANSICIONES.get(incidencia.estado, set()))
                    ],
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response({
            'ok': True,
            'id': incidencia.id,
            'estado': incidencia.estado,
            'estado_display': incidencia.get_estado_display(),
            'historial': HistorialEstadoSerializer(registro, context={'request': request}).data,
        })


class HistorialIncidenciaView(APIView):
    """HU004: línea de tiempo (de más antiguo a más reciente) de una incidencia.
    Cualquier usuario autenticado puede consultarla, igual que el estado visible en el feed."""
    permission_classes = [IsAuthenticated]

    def get(self, request, inc_id):
        if not Incidencia.objects.filter(id=inc_id).exists():
            return Response({'error': 'Incidencia no encontrada'}, status=status.HTTP_404_NOT_FOUND)
        qs = (
            HistorialEstado.objects
            .filter(incidencia_id=inc_id)
            .select_related('usuario_responsable')
            .order_by('fecha_cambio')
        )
        return Response(HistorialEstadoSerializer(qs, many=True, context={'request': request}).data)


class InformeMensualPDFView(APIView):
    """RF014 / HU005: informe mensual consolidado en PDF. GET ?anio=2026&mes=10"""
    permission_classes = [IsAdminUser]

    def get(self, request):
        hoy = timezone.localdate()
        try:
            anio = int(request.query_params.get('anio', hoy.year))
            mes = int(request.query_params.get('mes', hoy.month))
        except ValueError:
            return Response({'error': 'anio y mes deben ser numéricos'}, status=status.HTTP_400_BAD_REQUEST)
        if not (1 <= mes <= 12 and 2000 <= anio <= 2100):
            return Response({'error': 'Use ?anio=YYYY&mes=1-12'}, status=status.HTTP_400_BAD_REQUEST)

        pdf = generar_informe_mensual(anio, mes)
        return FileResponse(
            pdf, as_attachment=True, content_type='application/pdf',
            filename=f'informe_incidencias_{anio}_{mes:02d}.pdf',
        )


class AnunciosView(generics.ListAPIView):
    """Devuelve los anuncios activos a cualquier usuario."""
    permission_classes = [AllowAny]
    serializer_class = AnuncioSerializer
    pagination_class = None

    def get_queryset(self):
        return Anuncio.objects.filter(activo=True)


class RegistroView(generics.CreateAPIView):
    """RF004: Registro de ciudadano con validación biométrica"""
    serializer_class = RegistroUsuarioSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        return Response({
            'message': 'Usuario registrado exitosamente',
            'cedula': user.cedula,
            'metodo_verificacion': user.metodo_verificacion
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    """Login de ciudadano mediante cédula y contraseña, devuelve tokens JWT."""
    permission_classes = [AllowAny]

    def post(self, request):
        cedula = request.data.get('cedula')
        password = request.data.get('password')

        if not cedula or not password:
            return Response(
                {'error': 'Cédula y contraseña son requeridas'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            usuario = Usuario.objects.get(cedula=cedula)
        except Usuario.DoesNotExist:
            return Response({'error': 'Credenciales inválidas'}, status=status.HTTP_401_UNAUTHORIZED)

        user = authenticate(request, username=usuario.username, password=password)
        if user is None:
            return Response({'error': 'Credenciales inválidas'}, status=status.HTTP_401_UNAUTHORIZED)

        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'cedula': user.cedula,
            'username': user.username,
            'metodo_verificacion': user.metodo_verificacion,
        }, status=status.HTTP_200_OK)


class AdminAccessView(APIView):
    """Confirma que el JWT pertenece a una cuenta administrativa activa."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        return Response({'username': request.user.username})


class PerfilView(APIView):
    """Perfil del ciudadano logueado: datos, foto y estadísticas."""
    permission_classes = [IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get(self, request):
        serializer = PerfilSerializer(request.user, context={'request': request})
        return Response(serializer.data)

    def patch(self, request):
        foto = request.FILES.get('foto_perfil')
        if foto:
            request.user.foto_perfil = foto
            request.user.save(update_fields=['foto_perfil'])
        serializer = PerfilSerializer(request.user, context={'request': request})
        return Response(serializer.data)


class AdminLoginView(APIView):
    """Login para el panel administrativo, autentica por username (no cédula).
    Solo permite acceso a usuarios staff o superusuarios."""
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')

        if not username or not password:
            return Response(
                {'error': 'Usuario y contraseña son requeridos'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = authenticate(username=username, password=password)

        if user is None:
            return Response(
                {'error': 'Credenciales inválidas'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if not (user.is_staff or user.is_superuser):
            return Response(
                {'error': 'No tiene permisos de administrador'},
                status=status.HTTP_403_FORBIDDEN
            )

        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'username': user.username,
            'is_superuser': user.is_superuser,
        })