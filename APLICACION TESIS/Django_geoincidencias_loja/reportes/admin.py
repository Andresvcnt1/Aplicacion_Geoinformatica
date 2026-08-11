from django.contrib.gis import admin
from django.contrib.gis.forms.widgets import OSMWidget
from .models import Incidencia


@admin.register(Incidencia)
class IncidenciaAdmin(admin.GISModelAdmin):
    list_display = ('categoria', 'descripcion', 'estado', 'fecha_creacion', 'ubicacion')
    list_filter = ('categoria', 'estado', 'fecha_creacion')
    search_fields = ('descripcion',)
    
    gis_widget_kwargs = {
        'attrs': {
            'default_lon': -79.2239,
            'default_lat': -4.0085,
            'default_zoom': 13,
        }
    }

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        """Fuerza el uso del widget OSM para el campo ubicacion"""
        if db_field.name == 'ubicacion':
            kwargs['widget'] = OSMWidget(**self.gis_widget_kwargs)
        return super().formfield_for_dbfield(db_field, request, **kwargs)