from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.gis import admin as gis_admin
from django.contrib.gis.forms.widgets import OSMWidget
from .models import Anuncio, GeocercaMunicipal, Incidencia, Usuario, Pago

# ============================================
# 1. ADMINISTRACIÓN DE USUARIOS (RF004)
# ============================================
@admin.register(Usuario)
class UsuarioAdmin(UserAdmin):
    list_display = (
        'username', 'cedula', 'email', 'metodo_verificacion',
        'es_vip_display', 'is_staff', 'date_joined',
    )
    list_filter = ('metodo_verificacion', 'is_staff', 'is_active')
    search_fields = ('username', 'cedula', 'email')
    ordering = ('-date_joined',)

    @admin.display(boolean=True, description='VIP')
    def es_vip_display(self, obj):
        return obj.es_vip

    # Agregar campos personalizados a la vista de edición
    fieldsets = UserAdmin.fieldsets + (
        ('Información Ciudadana', {
            'fields': ('cedula', 'metodo_verificacion'),
        }),
        ('Suscripción', {
            'fields': ('vip_hasta',),
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

class CartoDBWidget(OSMWidget):
    """Widget de mapa usando CartoDB en vez del OSM directo,
    para evitar el bloqueo por política de uso de OpenStreetMap."""
    template_name = 'cartodb-osm.html'

@admin.register(Incidencia)
class IncidenciaAdmin(gis_admin.GISModelAdmin):
    list_display = (
        'categoria', 'descripcion', 'estado', 'prioritaria', 'anonimo',
        'fecha_creacion', 'ubicacion',
    )
    list_filter = ('categoria', 'estado', 'prioritaria', 'anonimo', 'fecha_creacion')
    search_fields = ('descripcion',)
    # El estado solo cambia con Incidencia.cambiar_estado() (panel web), para que
    # cada cambio quede en HistorialEstado. Editarlo aquí rompería la trazabilidad.
    readonly_fields = ('estado',)
    gis_widget = CartoDBWidget
    gis_widget_kwargs = {
        'attrs': {
            'default_lon': -79.2239,
            'default_lat': -4.0085,
            'default_zoom': 13,
        }
    }


# ============================================
# 3. ADMINISTRACIÓN DE GEOCERCAS (RF007)
# ============================================
@admin.register(GeocercaMunicipal)
class GeocercaMunicipalAdmin(gis_admin.GISModelAdmin):
    list_display = ('nombre', 'activa', 'fecha_creacion')
    list_filter = ('activa',)
    search_fields = ('nombre',)
    gis_widget = CartoDBWidget
    gis_widget_kwargs = {
        'attrs': {
            'default_lon': -79.2239,
            'default_lat': -4.0085,
            'default_zoom': 13,
        }
    }


# ============================================
# 4. PUBLICIDAD (modelo freemium)
# ============================================
@admin.register(Anuncio)
class AnuncioAdmin(admin.ModelAdmin):
    list_display = ('titulo', 'anunciante', 'activo', 'orden')
    list_editable = ('activo', 'orden')
    search_fields = ('titulo', 'anunciante')

@admin.register(Pago)
class PagoAdmin(admin.ModelAdmin):
    list_display = ('referencia', 'usuario', 'monto', 'metodo', 'marca',
                    'ultimos4', 'estado', 'simulado', 'fecha')
    list_filter = ('estado', 'metodo', 'simulado')
    search_fields = ('referencia', 'usuario__username', 'usuario__cedula')
    readonly_fields = [f.name for f in Pago._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False@admin.register(Pago)