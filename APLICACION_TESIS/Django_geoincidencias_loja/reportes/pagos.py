"""Pasarela de pago SIMULADA para la suscripción VIP.

Principios (valen también para una pasarela real):
- El servidor NUNCA recibe ni guarda el número completo de la tarjeta ni el CVV.
- Solo se registra la marca, los últimos 4 dígitos y una referencia del cobro.
- Con una pasarela real (PayPhone, Datafast, Stripe) el cobro lo hace ella y este
  servidor solo verifica el resultado con la referencia que ella devuelve.
"""
import re
import uuid

from .models import Pago

METODOS_VALIDOS = {'tarjeta'}
MARCAS_VALIDAS = {'visa', 'mastercard', 'amex', 'otra'}

# Tarjeta de prueba que simula un rechazo del emisor (termina en 0002)
ULTIMOS4_RECHAZADA = '0002'


class PagoInvalido(Exception):
    """Los datos del pago llegaron incompletos o con formato incorrecto."""


def validar_datos_pago(data):
    metodo = str(data.get('metodo', '')).strip().lower()
    if metodo not in METODOS_VALIDOS:
        raise PagoInvalido('Método de pago no válido.')

    marca = str(data.get('marca', 'otra')).strip().lower()
    if marca not in MARCAS_VALIDAS:
        marca = 'otra'

    ultimos4 = str(data.get('ultimos4', '')).strip()
    if not re.fullmatch(r'\d{4}', ultimos4):
        raise PagoInvalido('Faltan los últimos 4 dígitos de la tarjeta.')

    return {'metodo': metodo, 'marca': marca, 'ultimos4': ultimos4}


def registrar_pago(usuario, datos, monto, dias):
    """Crea el registro del cobro (aprobado o rechazado) y lo devuelve."""
    rechazado = datos['ultimos4'] == ULTIMOS4_RECHAZADA
    return Pago.objects.create(
        usuario=usuario,
        monto=monto,
        dias=dias,
        metodo=datos['metodo'],
        marca=datos['marca'],
        ultimos4=datos['ultimos4'],
        estado=Pago.Estado.RECHAZADO if rechazado else Pago.Estado.APROBADO,
        referencia='SIM-' + uuid.uuid4().hex[:12].upper(),
        simulado=True,
    )