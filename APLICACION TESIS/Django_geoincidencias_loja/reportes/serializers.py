from django.contrib.auth.password_validation import validate_password
from django.contrib.gis.geos import Point
from rest_framework import serializers

from .models import Usuario, Incidencia, GeocercaMunicipal


class IncidenciaSerializer(serializers.ModelSerializer):
    latitud = serializers.FloatField(write_only=True, required=True)
    longitud = serializers.FloatField(write_only=True, required=True)
    usuario_nombre = serializers.SerializerMethodField()
    usuario_foto = serializers.SerializerMethodField()

    class Meta:
        model = Incidencia
        fields = [
            'id', 'categoria', 'descripcion', 'foto', 'fecha_creacion',
            'estado', 'latitud', 'longitud', 'ubicacion', 'usuario_nombre', 'usuario_foto',
        ]
        extra_kwargs = {
            'ubicacion': {'required': False, 'allow_null': True},
            'foto': {'required': False, 'allow_null': True},
            'fecha_creacion': {'read_only': True},
            'estado': {'read_only': False},
        }

    def get_usuario_nombre(self, obj):
        if obj.usuario:
            nombre = obj.usuario.first_name or ''
            apellido = obj.usuario.last_name or ''
            nombre_completo = f"{nombre} {apellido}".strip()
            return nombre_completo if nombre_completo else obj.usuario.username
        return 'Ciudadano anónimo'

    def get_usuario_foto(self, obj):
        request = self.context.get('request')
        if obj.usuario and obj.usuario.foto_perfil and request:
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
        
        # Generar username automático
        validated_data['username'] = f"usuario_{cedula}"
        
        # Crear usuario
        user = Usuario.objects.create_user(
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

    class Meta:
        model = Usuario
        fields = [
            'cedula', 'first_name', 'last_name', 'email', 'metodo_verificacion',
            'foto_perfil_url', 'total_reportes', 'fecha_registro',
        ]

    def get_foto_perfil_url(self, obj):
        request = self.context.get('request')
        if obj.foto_perfil and request:
            return request.build_absolute_uri(obj.foto_perfil.url)
        return None

    def get_total_reportes(self, obj):
        return obj.incidencias.count()