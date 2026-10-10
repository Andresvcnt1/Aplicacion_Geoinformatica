from django.contrib.auth.password_validation import validate_password
from django.contrib.gis.geos import Point
from django.db.models import Count
from rest_framework import serializers

from .models import Anuncio, Usuario, Incidencia, GeocercaMunicipal, HistorialEstado


class IncidenciaSerializer(serializers.ModelSerializer):
    latitud = serializers.FloatField(write_only=True, required=True)
    longitud = serializers.FloatField(write_only=True, required=True)
    usuario_nombre = serializers.SerializerMethodField()
    usuario_foto = serializers.SerializerMethodField()
    estado_display = serializers.CharField(source='get_estado_display', read_only=True)

    class Meta:
        model = Incidencia
        fields = [
            'id', 'categoria', 'descripcion', 'foto', 'fecha_creacion',
            'estado', 'estado_display', 'latitud', 'longitud', 'ubicacion',
            'usuario_nombre', 'usuario_foto', 'anonimo', 'prioritaria',
        ]
        extra_kwargs = {
            'ubicacion': {'required': False, 'allow_null': True},
            'foto': {'required': True, 'allow_null': False},
            'fecha_creacion': {'read_only': True},
            # El ciudadano NO puede fijar el estado: solo cambia vía cambiar_estado()
            'estado': {'read_only': True},
            # Se calcula en el servidor según la suscripción del usuario
            'prioritaria': {'read_only': True},
        }

    def _autor_visible(self, obj):
        """Un reporte anónimo solo lo identifican el personal técnico y su propio autor."""
        if not obj.anonimo:
            return True
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        if user is None or not user.is_authenticated:
            return False
        return user.is_staff or obj.usuario_id == user.id

    # Mostrar Nombre y Apellido en las publicaciones
    def get_usuario_nombre(self, obj):
        if obj.usuario and self._autor_visible(obj):
            nombre = obj.usuario.first_name or ''
            apellido = obj.usuario.last_name or ''
            nombre_completo = f"{nombre} {apellido}".strip()
            return nombre_completo if nombre_completo else obj.usuario.cedula
        return 'Ciudadano anónimo'

    def get_usuario_foto(self, obj):
        request = self.context.get('request')
        if obj.usuario and obj.usuario.foto_perfil and request and self._autor_visible(obj):
            return request.build_absolute_uri(obj.usuario.foto_perfil.url)
        return None

    def validate(self, attrs):
        lat = attrs.get('latitud')
        lng = attrs.get('longitud')

        if lat is not None and lng is not None:
            punto = Point(lng, lat, srid=4326)
            dentro_de_geocerca = GeocercaMunicipal.objects.filter(
                area__contains=punto,
                activa=True
            ).exists()

            if not dentro_de_geocerca:
                raise serializers.ValidationError({
                    "ubicacion": "La ubicación reportada está fuera de la zona de competencia municipal."
                })

        return attrs

    def create(self, validated_data):
        lat = validated_data.pop('latitud')
        lng = validated_data.pop('longitud')
        validated_data['ubicacion'] = Point(lng, lat, srid=4326)
        return super().create(validated_data)


class HistorialEstadoSerializer(serializers.ModelSerializer):
    """Línea de tiempo de una incidencia (HU004). El responsable solo se muestra al personal."""
    estado_nuevo_display = serializers.CharField(source='get_estado_nuevo_display', read_only=True)
    responsable = serializers.SerializerMethodField()

    class Meta:
        model = HistorialEstado
        fields = [
            'id', 'estado_anterior', 'estado_nuevo', 'estado_nuevo_display',
            'fecha_cambio', 'observacion', 'responsable',
        ]

    def get_responsable(self, obj):
        request = self.context.get('request')
        if request and request.user.is_staff:
            return obj.usuario_responsable.username
        return None


class RegistroUsuarioSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = Usuario
        fields = ['cedula', 'first_name', 'last_name', 'username', 'email', 'password', 'password_confirm', 'metodo_verificacion']
        extra_kwargs = {
            'first_name': {'required': True},
            'last_name': {'required': False},
            'username': {'required': False},
        }

    def validate(self, attrs):
        if attrs.get('password') != attrs.get('password_confirm'):
            raise serializers.ValidationError({"password": "Las contraseñas no coinciden."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        cedula = validated_data.get('cedula')

        # Usar la cédula directamente como username
        username = cedula

        user = Usuario.objects.create_user(
            username=username,
            password=password,
            cedula=cedula,
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            email=validated_data.get('email', ''),
            metodo_verificacion=validated_data.get('metodo_verificacion', 'huella')
        )
        return user


class PerfilSerializer(serializers.ModelSerializer):
    foto_perfil_url = serializers.SerializerMethodField()
    total_reportes = serializers.SerializerMethodField()
    reportes_por_estado = serializers.SerializerMethodField()
    es_vip = serializers.BooleanField(read_only=True)

    class Meta:
        model = Usuario
        fields = [
            'cedula', 'first_name', 'last_name', 'email', 'metodo_verificacion',
            'foto_perfil_url', 'total_reportes', 'reportes_por_estado', 'fecha_registro',
            'es_vip', 'vip_hasta',
        ]
        read_only_fields = ['vip_hasta']

    def get_foto_perfil_url(self, obj):
        request = self.context.get('request')
        if obj.foto_perfil and request:
            return request.build_absolute_uri(obj.foto_perfil.url)
        return None

    def get_total_reportes(self, obj):
        return obj.incidencias.count()

    def get_reportes_por_estado(self, obj):
        # Claves = etiquetas de los 6 estados ('Recibido', 'En revisión', ...)
        conteo = dict(
            obj.incidencias.order_by().values_list('estado').annotate(n=Count('id'))
        )
        return {
            etiqueta: conteo.get(valor, 0)
            for valor, etiqueta in Incidencia.Estado.choices
        }


class AnuncioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Anuncio
        fields = ['id', 'anunciante', 'titulo', 'texto', 'imagen', 'enlace']