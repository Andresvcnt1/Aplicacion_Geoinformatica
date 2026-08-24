from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.gis import admin as gis_admin
from django.contrib.gis.forms.widgets import OSMWidget
from .models import Incidencia, Usuario


# ============================================
# 1. ADMINISTRACIÓN DE USUARIOS (RF004)
# ============================================
@admin.register(Usuario)
class UsuarioAdmin(UserAdmin):
    list_display = ('username', 'cedula', 'email', 'metodo_verificacion', 'is_staff', 'date_joined')
    list_filter = ('metodo_verificacion', 'is_staff', 'is_active')
    search_fields = ('username', 'cedula', 'email')
    ordering = ('-date_joined',)
    
    # Agregar campos personalizados a la vista de edición
    fieldsets = UserAdmin.fieldsets + (
        ('Información Ciudadana', {
            'fields': ('cedula', 'metodo_verificacion'),
        }),
    )
    
    # Agregar campos al formulario de "Crear nuevo usuario"
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Información Ciudadana', {
            'classes': ('wide',),
            'fields': ('username', 'cedula', 'email', 'password1', 'password2', 'metodo_verificacion'),
        }),
    )


# ============================================
# 2. ADMINISTRACIÓN DE INCIDENCIAS (GeoDjango)
# ============================================
@admin.register(Incidencia)
class IncidenciaAdmin(gis_admin.GISModelAdmin):
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