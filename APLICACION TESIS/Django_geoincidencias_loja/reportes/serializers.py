from rest_framework import serializers
from django.contrib.gis.geos import Point
from .models import Incidencia


class IncidenciaSerializer(serializers.ModelSerializer):
    latitud = serializers.FloatField(write_only=True, required=True)
    longitud = serializers.FloatField(write_only=True, required=True)

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
            'ubicacion'
        ]

        extra_kwargs = {
            'ubicacion': {'required': False, 'allow_null': True},
            'foto': {'required': False, 'allow_null': True},
            'fecha_creacion': {'read_only': True},
            'estado': {'read_only': False},
        }

    def create(self, validated_data):
        lat = validated_data.pop('latitud')
        lng = validated_data.pop('longitud')

        validated_data['ubicacion'] = Point(lng, lat, srid=4326)

        return super().create(validated_data)