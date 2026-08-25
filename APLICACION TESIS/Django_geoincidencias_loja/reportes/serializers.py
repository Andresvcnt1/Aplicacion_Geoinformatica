from django.contrib.auth.password_validation import validate_password
from .models import Usuario
from rest_framework import serializers
from django.contrib.gis.geos import Point
from .models import Incidencia


class IncidenciaSerializer(serializers.ModelSerializer):
    latitud = serializers.FloatField(write_only=True, required=True)
    longitud = serializers.FloatField(write_only=True, required=True)
    usuario_nombre = serializers.SerializerMethodField()
    usuario_foto = serializers.SerializerMethodField()

    class Meta:
        model = Incidencia
        fields = [
            'id',
            'categoria',
            'descripcion',
            'foto',
            'fecha_creacion',
            'estado',
            'latitud',
            'longitud',
            'ubicacion',
            'usuario_nombre',
            'usuario_foto',
        ]

        extra_kwargs = {
            'ubicacion': {'required': False, 'allow_null': True},
            'foto': {'required': False, 'allow_null': True},
            'fecha_creacion': {'read_only': True},
            'estado': {'read_only': False},
        }

    def get_usuario_nombre(self, obj):
        return obj.usuario.username if obj.usuario else 'Ciudadano anónimo'

    def get_usuario_foto(self, obj):
        request = self.context.get('request')
        if obj.usuario and obj.usuario.foto_perfil and request:
            return request.build_absolute_uri(obj.usuario.foto_perfil.url)
        return None

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
        fields = ['cedula', 'username', 'email', 'password', 'password_confirm', 'metodo_verificacion']

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Las contraseñas no coinciden"})

        cedula = attrs.get('cedula', '')
        if len(cedula) != 10 or not cedula.isdigit():
            raise serializers.ValidationError({"cedula": "Cédula debe tener 10 dígitos"})

        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')

        cedula = validated_data.get('cedula')
        validated_data['username'] = f"usuario_{cedula}"

        user = Usuario.objects.create_user(password=password, **validated_data)
        return user


class PerfilSerializer(serializers.ModelSerializer):
    foto_perfil_url = serializers.SerializerMethodField()
    total_reportes = serializers.SerializerMethodField()

    class Meta:
        model = Usuario
        fields = [
            'cedula',
            'username',
            'email',
            'metodo_verificacion',
            'foto_perfil_url',
            'total_reportes',
            'fecha_registro',
        ]

    def get_foto_perfil_url(self, obj):
        request = self.context.get('request')
        if obj.foto_perfil and request:
            return request.build_absolute_uri(obj.foto_perfil.url)
        return None

    def get_total_reportes(self, obj):
        return obj.incidencias.count()