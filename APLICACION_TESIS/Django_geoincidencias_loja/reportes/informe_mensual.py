from io import BytesIO
from xml.sax.saxutils import escape

from django.db.models import Count
from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from .models import Incidencia

MESES = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
]
AZUL = colors.HexColor('#1F3A5F')
GRIS = colors.HexColor('#F2F4F7')


def _tabla(datos, anchos):
    t = Table(datos, colWidths=anchos, repeatRows=1)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), AZUL),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, GRIS]),
        ('GRID', (0, 0), (-1, -1), 0.25, colors.grey),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    return t


def _fecha(dt):
    return timezone.localtime(dt).strftime('%d/%m/%Y %H:%M')


def generar_informe_mensual(anio: int, mes: int) -> BytesIO:
    """Incidencias CREADAS en el mes, consolidadas y detalladas por estado."""
    qs = (
        Incidencia.objects
        .filter(fecha_creacion__year=anio, fecha_creacion__month=mes)
        .prefetch_related('historial')
        .order_by('fecha_creacion')
    )
    total = qs.count()
    conteo = dict(qs.order_by().values_list('estado').annotate(n=Count('id')))

    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer, pagesize=landscape(A4),
        leftMargin=2 * cm, rightMargin=2 * cm, topMargin=1.8 * cm, bottomMargin=1.8 * cm,
        title=f'Informe mensual {mes:02d}-{anio}',
    )
    estilos = getSampleStyleSheet()
    celda = estilos['BodyText']
    celda.fontSize = 8
    celda.leading = 10

    el = [
        Paragraph('Geoincidencias Loja', estilos['Title']),
        Paragraph(f'Informe mensual consolidado: {MESES[mes - 1].capitalize()} {anio}', estilos['Heading2']),
        Paragraph(f'Total de incidencias reportadas: <b>{total}</b> '
                  f'(generado el {timezone.localtime().strftime("%d/%m/%Y %H:%M")})', estilos['Normal']),
        Spacer(1, 0.4 * cm),
    ]

    # Resumen por estado
    resumen = [['Estado', 'Cantidad', '%']]
    for valor, etiqueta in Incidencia.Estado.choices:
        n = conteo.get(valor, 0)
        resumen.append([etiqueta, n, f'{n / total * 100:.1f}%' if total else '0.0%'])
    el += [_tabla(resumen, [8 * cm, 4 * cm, 4 * cm]), Spacer(1, 0.5 * cm)]

    # Detalle agrupado por estado
    categorias = dict(Incidencia.CATEGORIAS)
    for valor, etiqueta in Incidencia.Estado.choices:
        items = [i for i in qs if i.estado == valor]
        if not items:
            continue
        el.append(Paragraph(f'{etiqueta} ({len(items)})', estilos['Heading3']))
        filas = [['ID', 'Categoría', 'Reportada', 'Últ. actualización', 'Ubicación (lat, lon)', 'Última observación']]
        for i in items:
            ultimo = next(iter(i.historial.all()), None)  # historial ordena -fecha_cambio
            obs = (ultimo.observacion if ultimo else '') or '—'
            filas.append([
                i.pk,
                Paragraph(escape(categorias.get(i.categoria, i.categoria)), celda),
                _fecha(i.fecha_creacion),
                _fecha(i.fecha_ultima_actualizacion),
                f'{i.ubicacion.y:.5f}, {i.ubicacion.x:.5f}',
                Paragraph(escape(obs[:160]), celda),
            ])
        el += [_tabla(filas, [1.2 * cm, 4.6 * cm, 3 * cm, 3.2 * cm, 3.8 * cm, 9.9 * cm]), Spacer(1, 0.4 * cm)]

    if not total:
        el.append(Paragraph('No se registraron incidencias en este período.', estilos['Normal']))

    def pie(canvas, d):
        canvas.setFont('Helvetica', 8)
        canvas.drawRightString(landscape(A4)[0] - 2 * cm, 1 * cm, f'Página {d.page}')

    doc.build(el, onFirstPage=pie, onLaterPages=pie)
    buffer.seek(0)
    return buffer